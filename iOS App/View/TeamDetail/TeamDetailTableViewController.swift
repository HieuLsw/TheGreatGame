//
//  TeamDetailTableViewController.swift
//  TheGreatGame
//
//  Created by Олег on 05.05.17.
//  Copyright © 2017 The Great Game. All rights reserved.
//

import UIKit
import TheGreatKit
import Shallows
import Avenues

struct TeamDetailPreLoaded {
    
    let name: String?
    let shortName: String?
    let badges: Team.Badges?
    let summary: String?
    
}

extension Team.Compact {
    
    func preLoaded() -> TeamDetailPreLoaded {
        return TeamDetailPreLoaded(name: self.name, shortName: self.shortName, badges: self.badges, summary: nil)
    }
    
}

extension Group.Team {
    
    func preLoaded() -> TeamDetailPreLoaded {
        return TeamDetailPreLoaded(name: self.name, shortName: nil, badges: self.badges, summary: nil)
    }
    
}

extension Match.Team {
    
    func preLoaded() -> TeamDetailPreLoaded {
        return TeamDetailPreLoaded(name: self.name, shortName: self.shortName, badges: self.badges, summary: nil)
    }
    
}

class TeamDetailTableViewController: TheGreatGame.TableViewController, Refreshing, Showing {
    
    // MARK: - Outlets
    @IBOutlet weak var favoriteButton: UIButton!
    
    // MARK: - Data source
    var team: Team.Full?
    
    // MARK: - Injections
    var preloadedTeam: TeamDetailPreLoaded?
    var makeTeamDetailVC: (Group.Team) -> UIViewController = runtimeInject
    var makeMatchDetailVC: (Match.Compact) -> UIViewController = runtimeInject
    var makeAvenue: (CGSize) -> Avenue<URL, UIImage> = runtimeInject
    var isFavorite: () -> Bool = runtimeInject
    var updateFavorite: (Bool) -> () = runtimeInject

    // MARK: - Services
    var mainBadgeAvenue: Avenue<URL, UIImage>!
    var smallBadgesAvenue: Avenue<URL, UIImage>!
    
    // MARK: - Cell Fillers
    var matchCellFiller: MatchCellFiller!
    var teamGroupCellFiller: TeamGroupCellFiller!
    
    // MARK: - Connections
    var reactiveTeam: Reactive<Team.Full>!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.smallBadgesAvenue = makeAvenue(CGSize(width: 30, height: 30))
        self.mainBadgeAvenue = makeAvenue(CGSize(width: 50, height: 50))
        self.matchCellFiller = MatchCellFiller(avenue: smallBadgesAvenue,
                                               scoreMode: .dateAndTime,
                                               isFavorite: { _ in return false })
        self.teamGroupCellFiller = TeamGroupCellFiller(avenue: smallBadgesAvenue)
        registerForPeekAndPop()
        self.subscribe()
        configure(tableView)
        configure(navigationItem)
        configure(favoriteButton: favoriteButton)
        self.reactiveTeam.update.fire(errorDelegate: self)
    }
    
    func subscribe() {
        reactiveTeam.didUpdate.subscribe(self, with: TeamDetailTableViewController.setup)
    }
    
    override var previewActionItems: [UIPreviewActionItem] {
        let favoriteAction = UIPreviewAction(title: isFavorite() ? "Unfavorite" : "Favorite", style: .default) { (action, controller) in
            if let controller = controller as? TeamDetailTableViewController {
                controller.updateFavorite(!controller.isFavorite())
            } else {
                fault("Wrong VC")
            }
        }
        return [favoriteAction]
    }
    
    func setup(with team: Team.Full) {
        self.team = team
        self.tableView.reloadData()
        self.configure(self.navigationItem)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func didPullToRefresh(_ sender: UIRefreshControl) {
        reactiveTeam.update.fire(activityIndicator: pullToRefreshIndicator, errorDelegate: self)
    }
    
    @IBAction func didPressFavoriteButton(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        updateFavorite(sender.isSelected)
    }


    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    let detailSectionIndex = 0
    let groupSectionIndex = 1
    let matchesSectionIndex = 2
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case detailSectionIndex:
            return 1
        case groupSectionIndex:
            return team?.group.teams.count ?? 0
        case matchesSectionIndex:
            return team?.matches.count ?? 0
        default:
            fatalError("What?!")
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case groupSectionIndex:
            return team?.group.title
        default:
            return nil
        }
    }
        
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case detailSectionIndex:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeamDetailTeamDetail", for: indexPath)
            configureCell(cell, forRowAt: indexPath)
            return cell
        case groupSectionIndex:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeamDetailGroupTeam", for: indexPath)
            configureCell(cell, forRowAt: indexPath)
            return cell
        case matchesSectionIndex:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeamDetailMatch", for: indexPath)
            configureCell(cell, forRowAt: indexPath)
            return cell
        default:
            fatalError("What?!")
        }
    }
    
    func configureCell(_ cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        switch cell {
        case let match as MatchTableViewCell:
            configureMatchCell(match, forRowAt: indexPath)
        case let teamGroup as TeamGroupTableViewCell:
            configureTeamGroupCell(teamGroup, forRowAt: indexPath)
        case let teamDetail as TeamDetailInfoTableViewCell:
            configureTeamDetailsCell(teamDetail, forRowAt: indexPath)
        default:
            fault("Such cell is not registered \(type(of: cell))")
        }
    }
    
    func configureTeamDetailsCell(_ cell: TeamDetailInfoTableViewCell, forRowAt indexPath: IndexPath) {
        cell.selectionStyle = .none
        if let team = team {
            mainBadgeAvenue.register(cell.badgeImageView, for: team.badges.flag)
            cell.nameLabel.text = team.name
            cell.teamSummaryLabel.text = team.summary
        } else if let preloaded = preloadedTeam {
            cell.nameLabel.text = preloaded.name
            cell.teamSummaryLabel.text = preloaded.summary
            if let badgeURL = preloaded.badges?.flag {
                mainBadgeAvenue.register(cell.badgeImageView, for: badgeURL)
            }
        }
    }
    
    func configureMatchCell(_ cell: MatchTableViewCell, forRowAt indexPath: IndexPath) {
        guard let match = team?.matches[indexPath.row] else {
            fault("No team still?")
            return
        }
        matchCellFiller.setup(cell, with: match, forRowAt: indexPath)
    }
    
    func configureTeamGroupCell(_ cell: TeamGroupTableViewCell, forRowAt indexPath: IndexPath) {
        guard let groupTeam = team?.group.teams[indexPath.row] else {
            fault("No team, really?")
            return
        }
        teamGroupCellFiller.setup(cell, with: groupTeam, forRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        showViewController(for: indexPath)
    }
    
    func viewController(for indexPath: IndexPath) -> UIViewController? {
        switch indexPath.section {
        case groupSectionIndex:
            let team = self.team?.group.teams[indexPath.row]
            return team.map(makeTeamDetailVC)
        case matchesSectionIndex:
            let match = self.team?.matches[indexPath.row]
            return match.map(makeMatchDetailVC)
        default:
            return nil
        }
    }

}

// MARK: - Configurations
extension TeamDetailTableViewController {
    
    fileprivate func registerFor3DTouch() {
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: tableView)
        }
    }
    
    fileprivate func configure(_ navigationItem: UINavigationItem) {
        navigationItem.title = team?.name ?? preloadedTeam?.name
    }
    
    fileprivate func configure(favoriteButton: UIButton) {
        favoriteButton.isSelected = isFavorite()
    }
    
    fileprivate func configure(_ tableView: UITableView) {
        tableView <- {
            $0.register(UINib.init(nibName: "MatchTableViewCell", bundle: nil), forCellReuseIdentifier: "TeamDetailMatch")
            $0.register(UINib.init(nibName: "TeamGroupTableViewCell", bundle: nil), forCellReuseIdentifier: "TeamDetailGroupTeam")
            $0.register(UINib.init(nibName: "TeamDetailInfoTableViewCell", bundle: nil), forCellReuseIdentifier: "TeamDetailTeamDetail")
            $0.estimatedRowHeight = 55
            $0.rowHeight = UITableViewAutomaticDimension
        }
    }
    
}

extension TeamDetailTableViewController : UIViewControllerPreviewingDelegate {
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        return viewController(for: location, previewingContext: previewingContext)
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        show(viewControllerToCommit, sender: self)
    }
    
}
