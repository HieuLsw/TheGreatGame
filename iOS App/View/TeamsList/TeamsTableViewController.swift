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

extension Set {
    
    mutating func updatePresence(_ element: Element, shouldBeInSet: Bool) {
        if shouldBeInSet {
            insert(element)
        } else {
            remove(element)
        }
    }
    
}

class TeamsTableViewController: TheGreatGame.TableViewController, Refreshing {
    
    // MARK: - Data source
    var teams: [Team.Compact] = []
    
    // MARK: - Injections
    var resource: Resource<[Team.Compact]>!
    var makeTeamDetailVC: (Team.Compact) -> UIViewController = runtimeInject
    var makeAvenue: (CGSize) -> SymmetricalAvenue<URL, UIImage> = runtimeInject
    
    var isFavorite: (Team.ID) -> Bool = runtimeInject
    var updateFavorite: (Team.ID, Bool) -> () = runtimeInject

    // MARK: - Services
    var avenue: SymmetricalAvenue<URL, UIImage>!
    var pullToRefreshActivities: NetworkActivityIndicatorManager!
    
    // MARK: - Connections
    var shouldReloadData: SignedSubscribe<Void>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        subscribe()
        registerFor3DTouch()
        configure(tableView)
        self.pullToRefreshActivities = make()
        self.avenue = makeAvenue(CGSize(width: 30, height: 30))
        configure(avenue)
        self.resource.load(completion: reloadData(with:source:))
    }
    
    func subscribe() {
        shouldReloadData?
            .mainThread()
            .drop(eventsSignedBy: self)
            .unsigned
            .subscribe(self.tableView, with: UITableView.reloadData)
        shouldReloadData = nil
    }
    
    fileprivate func reloadData(with teams: [Team.Compact], source: Source) {
        if self.teams.isEmpty && source.isAbsoluteTruth {
            self.teams = teams
            let ips = teams.indices.map({ IndexPath.init(row: $0, section: 0) })
            tableView.insertRows(at: ips, with: UITableViewRowAnimation.automatic)
        } else {
            self.teams = teams
            tableView.reloadData()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func didPullToRefresh(_ sender: UIRefreshControl) {
        resource.reload(connectingToIndicator: pullToRefreshActivities,
                        completion: self.reloadData(with:source:))
    }
    
    func didFetchImage(with url: URL) {
        guard let indexPath = teams.index(where: { $0.badges.large == url }).map({ IndexPath(row: $0, section: 0) }) else {
            fault("No team with badge url: \(url)")
            return
        }
        if let cell = tableView.cellForRow(at: indexPath) {
            configureCell(cell, forRowAt: indexPath, afterImageDownload: true)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return teams.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TeamCompact", for: indexPath)
        configureCell(cell, forRowAt: indexPath)
        return cell
    }
    
    func configureCell(_ cell: UITableViewCell, forRowAt indexPath: IndexPath, afterImageDownload: Bool = false) {
        switch cell {
        case let teamCompact as TeamCompactTableViewCell:
            configureTeamCompactCell(teamCompact, forRowAt: indexPath, afterImageDownload: afterImageDownload)
        default:
            fault(type(of: cell))
        }
    }
    
    func configureTeamCompactCell(_ cell: TeamCompactTableViewCell, forRowAt indexPath: IndexPath, afterImageDownload: Bool) {
        let team = teams[indexPath.row]
        let badgeURL = team.badges.large
        if !afterImageDownload {
            avenue.prepareItem(at: badgeURL)
        }
        cell.favoriteSwitch.isOn = isFavorite(team.id)
        cell.nameLabel.text = team.name
        cell.shortNameLabel.text = team.shortName
        cell.badgeImageView.setImage(avenue.item(at: badgeURL), afterDownload: true)
        cell.onSwitch = { isFavorite in
            if let ipath = self.tableView.indexPath(for: cell) {
                let team = self.teams[ipath.row]
                self.updateFavorite(team.id, isFavorite)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let team = teams[indexPath.row]
        let detail = teamDetailViewController(for: team)
        navigationController?.pushViewController(detail, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    fileprivate func teamDetailViewController(for team: Team.Compact) -> UIViewController {
        return makeTeamDetailVC(team)
    }

}

// MARK: - Configurations
extension TeamsTableViewController {
    
    fileprivate func registerFor3DTouch() {
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: tableView)
        }
    }
    
    fileprivate func configure(_ avenue: Avenue<URL, URL, UIImage>) {
        avenue.onStateChange = { [weak self] url in
            assert(Thread.isMainThread)
            self?.didFetchImage(with: url)
        }
        avenue.onError = {
            print($0)
        }
    }
    
    fileprivate func configure(_ tableView: UITableView) {
        tableView.register(UINib.init(nibName: "TeamCompactTableViewCell", bundle: nil),
                           forCellReuseIdentifier: "TeamCompact")
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableViewAutomaticDimension
    }
    
}

// MARK: - Peek & Pop
extension TeamsTableViewController : UIViewControllerPreviewingDelegate {
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = tableView.indexPathForRow(at: location) else {
            return nil
        }
        let team = teams[indexPath.row]
        let teamDetail = teamDetailViewController(for: team)
        
        let cellRect = tableView.rectForRow(at: indexPath)
        let sourceRect = previewingContext.sourceView.convert(cellRect, from: tableView)
        previewingContext.sourceRect = sourceRect
        
        return teamDetail
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        show(viewControllerToCommit, sender: self)
    }
    
}
