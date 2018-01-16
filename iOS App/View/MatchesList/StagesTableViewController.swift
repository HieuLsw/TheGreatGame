//
//  TeamsTableViewController.swift
//  TheGreatGame
//
//  Created by Олег on 03.05.17.
//  Copyright © 2017 The Great Game. All rights reserved.
//

import UIKit
import TheGreatKit
import Shallows
import Avenues
import Alba

let monthAndDayFormatter = DateFormatter() <- {
    $0.setLocalizedDateFormatFromTemplate("MMMMd")
}

class StagesTableViewController: TheGreatGame.TableViewController, Showing {
    
    // MARK: - Data source
    var stages: [Stage]!
    
    // MARK: - Injections
    var makeMatchDetailVC: (Match.Compact, String) -> UIViewController = runtimeInject
    var makeAvenue: (CGSize) -> SymmetricalAvenue<URL, UIImage> = runtimeInject    
    var isFavorite: (Match.Compact) -> Bool = runtimeInject

    // MARK: - Services
    var avenue: SymmetricalAvenue<URL, UIImage>!
    
    // MARK: - Cell Fillers
    var matchCellFiller: MatchCellFiller!
    
    // MARK: - Connections
    var reactiveStages: Reactive<[Stage]>!
    var shouldReloadTable: MainThreadSubscribe<Void>?
    var shouldReloadData: MainThreadSubscribe<Void>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        registerForPeekAndPop()
        self.subscribe()
        configure(tableView)
        self.avenue = makeAvenue(CGSize(width: 30, height: 30))
        self.matchCellFiller = MatchCellFiller(avenue: avenue,
                                               scoreMode: .timeOnly,
                                               isFavorite: { [unowned self] in self.isFavorite($0) })
        configure(avenue)
        self.reactiveStages.update.fire(errorDelegate: self)
    }
    
    func subscribe() {
        shouldReloadTable?.flatSubscribe(self, with: { obj, _ in obj.tableView.reloadData() })
        shouldReloadTable = nil
        shouldReloadData?.subscribe(self, with: StagesTableViewController.reload)
        shouldReloadData = nil
        reactiveStages.didUpdate.subscribe(self, with: StagesTableViewController.reloadData)
    }
    
    fileprivate func reloadData(stages: [Stage]) {
        if self.stages.isEmpty {
            self.stages = stages
            tableView.insertSections(IndexSet.init(integersIn: 0 ... stages.count - 1), with: UITableViewRowAnimation.top)
        } else {
            self.stages = stages
            tableView.reloadData()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func didPullToRefresh(_ sender: UIRefreshControl) {
        self.reload()
    }
    
    func reload() {
        reactiveStages.update.fire(activityIndicator: pullToRefreshIndicator, errorDelegate: self)
    }
    
    func didFetchImage(with url: URL) {
        var paths: [IndexPath] = []
        for (stage, stageIndex) in zip(stages, stages.indices) {
            for (match, matchIndex) in zip(stage.matches, stage.matches.indices) {
                if match.teams.contains(where: { $0.badges.large == url }) {
                    paths.append(IndexPath(row: matchIndex, section: stageIndex))
                }
            }
        }
        for indexPath in paths {
            if let cell = tableView.cellForRow(at: indexPath) {
                configureCell(cell, forRowAt: indexPath, afterImageDownload: true)
            }
        }
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return stages.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stages[section].matches.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let stage = stages[section]
        let stageDate = stage.matches.first?.date
        let stageDateString = stageDate.map(monthAndDayFormatter.string(from:)) ?? "NO DATE"
        return "\(stage.title)\n\(stageDateString)"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MatchListMatch", for: indexPath)
        configureCell(cell, forRowAt: indexPath)
        return cell
    }
    
    func configureCell(_ cell: UITableViewCell, forRowAt indexPath: IndexPath, afterImageDownload: Bool = false) {
        switch cell {
        case let match as MatchTableViewCell:
            configureMatchCell(match, forRowAt: indexPath, afterImageDownload: afterImageDownload)
        default:
            fault(type(of: cell))
        }
    }
    
    func configureMatchCell(_ cell: MatchTableViewCell, forRowAt indexPath: IndexPath, afterImageDownload: Bool) {
        let match = stages[indexPath.section].matches[indexPath.row]
        matchCellFiller.setup(cell, with: match, forRowAt: indexPath, afterImageDownload: afterImageDownload)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        showViewController(for: indexPath)
    }
    
    func viewController(for indexPath: IndexPath) -> UIViewController? {
        let stage = stages[indexPath.section]
        return makeMatchDetailVC(stage.matches[indexPath.row], stage.title)
    }
    
}

// MARK: - Configurations
extension StagesTableViewController {
        
    fileprivate func configure(_ avenue: Avenue<URL, URL, UIImage>) {
        avenue.onStateChange = { [weak self] url in
            assert(Thread.isMainThread)
            self?.didFetchImage(with: url)
        }
        avenue.onError = { er, _ in
            print(er)
        }
    }
    
    fileprivate func configure(_ tableView: UITableView) {
        tableView.register(UINib.init(nibName: "MatchTableViewCell", bundle: nil),
                           forCellReuseIdentifier: "MatchListMatch")
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableViewAutomaticDimension
    }
    
}

extension StagesTableViewController {
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        return viewController(for: location, previewingContext: previewingContext)
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        show(viewControllerToCommit, sender: self)
    }
    
}