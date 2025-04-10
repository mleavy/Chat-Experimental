//
//  UIList-mleavy.swift
//  Chat
//
//  Created by Mike Leavy on 10/3/24.
//

//
//  UIList.swift
//
//
//  Created by Alisa Mylnikova on 24.02.2023.
//

import SwiftUI

//mleavy:
let isFillFromBottom: Bool = true

struct UIList<MessageContent: View, InputView: View>: UIViewRepresentable {

    typealias MessageBuilderClosure = ChatView<MessageContent, InputView, DefaultMessageMenuAction>.MessageBuilderClosure

    @Environment(\.chatTheme) private var theme

    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var inputViewModel: InputViewModel

    @Binding var isScrolledToBottom: Bool
    @Binding var shouldScrollToTop: () -> ()
    @Binding var tableContentHeight: CGFloat

    var messageBuilder: MessageBuilderClosure?
    var mainHeaderBuilder: (()->AnyView)?
    var headerBuilder: ((Date)->AnyView)?
    var inputView: InputView

    let type: ChatType
    let showDateHeaders: Bool
    let isScrollEnabled: Bool
    let avatarSize: CGFloat
    let showMessageMenuOnLongPress: Bool
    let tapAvatarClosure: ChatView.TapAvatarClosure?
    let tapReactionClosure: ReactionTappedClosure?
    let paginationHandler: PaginationHandler?
    let messageUseMarkdown: Bool
    let showMessageTimeView: Bool
    let messageFont: UIFont
    let sections: [MessagesSection]
    let ids: [String]
    
    let inputManager: CustomInputManager

    @State private var isScrolledToTop = false

    private let updatesQueue = DispatchQueue(label: "updatesQueue", qos: .utility)
    @State private var updateSemaphore = DispatchSemaphore(value: 1)
    @State private var tableSemaphore = DispatchSemaphore(value: 0)

    func makeUIView(context: Context) -> UIView {
        let tableView = UITableView(frame: .zero, style: .grouped)
        if !theme.extensions.isKeyboardInteractive {
            tableView.translatesAutoresizingMaskIntoConstraints = false
        }
        tableView.separatorStyle = .none
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        //mleavy: no transform when filling top to bottom
        if isFillFromBottom {
            tableView.transform = CGAffineTransform.identity.rotated(by: (type == .conversation ? .pi : 0)).scaledBy(x: theme.extensions.showsScrollIndicator ? -1 : 1, y: 1)
        }
        else {
            tableView.transform = CGAffineTransform(rotationAngle: (type == .conversation ? 0 : 0))
        }

        tableView.showsVerticalScrollIndicator = theme.extensions.showsScrollIndicator
        tableView.estimatedSectionHeaderHeight = 1
        tableView.estimatedSectionFooterHeight = UITableView.automaticDimension
        tableView.backgroundColor = UIColor(theme.colors.mainBackground)
        tableView.scrollsToTop = false
        tableView.isScrollEnabled = isScrollEnabled
        //mleavy
        tableView.keyboardDismissMode = theme.extensions.isKeyboardInteractive ? .interactive : .onDrag
        tableView.contentInset = .init(top: theme.extensions.conversaionViewInsets.top,
                                       left: theme.extensions.conversaionViewInsets.leading,
                                       bottom: theme.extensions.conversaionViewInsets.bottom,
                                       right: theme.extensions.conversaionViewInsets.trailing)

        NotificationCenter.default.addObserver(forName: .onScrollToBottom, object: nil, queue: nil) { _ in
            DispatchQueue.main.async {
                if !context.coordinator.sections.isEmpty {
                    //mleavy - NO reverse when filling top to bottom
                    if isFillFromBottom {
                        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .bottom, animated: true)
                    }
                    else {
                        //                    tableView.scrollRectToVisible(.init(x: 0,
                        //                                                        y: tableView.contentSize.height - 1,
                        //                                                        width: tableView.frame.size.width,
                        //                                                        height: 1), animated: true)
                        let section = context.coordinator.sections.count-1
                        if section >= 0 {
                            let row = context.coordinator.sections[section].rows.count-1
                            tableView.scrollToRow(at: IndexPath(row: row, section: section), at: .bottom, animated: true)
                            print("scrolling to section \(section), row \(row)")
                        }
                    }

                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: .onReloadData, object: nil, queue: nil) { _ in
            DispatchQueue.main.async {
                tableView.reloadData()
            }
        }

        DispatchQueue.main.async {
            shouldScrollToTop = {
                tableView.contentOffset = CGPoint(x: 0, y: tableView.contentSize.height - tableView.frame.height)
            }
        }
        
        if theme.extensions.isKeyboardInteractive {
            let view = UIView(frame: .zero)
            let internalView = UIView(frame: .zero)
            
            internalView.addSubview(tableView)
            tableView.translatesAutoresizingMaskIntoConstraints = false
            
            let inputContainer = inputManager.inputView
            internalView.addSubview(inputContainer)
            inputContainer.translatesAutoresizingMaskIntoConstraints = false
            
            view.addSubview(internalView)
            internalView.translatesAutoresizingMaskIntoConstraints = false
            
            tableView.tag = 777
            internalView.tag = 747
            
            view.keyboardLayoutGuide.followsUndockedKeyboard = true
            
            NSLayoutConstraint.activate([
                internalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                internalView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                internalView.topAnchor.constraint(equalTo: view.topAnchor),
            ])
            
            NSLayoutConstraint.activate([
                inputContainer.leadingAnchor.constraint(equalTo: internalView.leadingAnchor, constant: theme.extensions.inputViewPadding.leading),
                inputContainer.trailingAnchor.constraint(equalTo: internalView.trailingAnchor, constant: -theme.extensions.inputViewPadding.trailing),
                inputContainer.bottomAnchor.constraint(equalTo: internalView.bottomAnchor, constant: -theme.extensions.inputViewPadding.bottom),
                inputContainer.heightAnchor.constraint(equalToConstant: theme.extensions.inputViewDefaultHeight)
            ])
            
            NSLayoutConstraint.activate([
                tableView.leadingAnchor.constraint(equalTo: internalView.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: internalView.trailingAnchor),
                tableView.topAnchor.constraint(equalTo: internalView.topAnchor),
                tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor, constant: -theme.extensions.inputViewPadding.top)
            ])
            
            let textFieldOnKeyboard = view.keyboardLayoutGuide.topAnchor.constraint(equalTo: internalView.bottomAnchor, constant: 0)
            view.keyboardLayoutGuide.setConstraints([textFieldOnKeyboard], activeWhenAwayFrom: .top)
            
            return view
        }
        else {
            return tableView
        }
    }

    func updateUIView(_ uiView: UIView, context: Context) {
                
        let tableView: UITableView!
        if theme.extensions.isKeyboardInteractive {
            tableView = ((uiView.viewWithTag(747))!.viewWithTag(777) as! UITableView)
        }
        else {
            tableView = (uiView as! UITableView)
        }
                
        if !isScrollEnabled {
            DispatchQueue.main.async {
                tableContentHeight = tableView.contentSize.height
            }
        }

        if context.coordinator.sections == sections {
            return
        }
        updatesQueue.async {
            updateSemaphore.wait()

            if context.coordinator.sections == sections {
                updateSemaphore.signal()
                return
            }

            if context.coordinator.sections.isEmpty {
                DispatchQueue.main.async {
                    context.coordinator.sections = sections
                    tableView.reloadData()
                    if !isScrollEnabled {
                        DispatchQueue.main.async {
                            tableContentHeight = tableView.contentSize.height
                        }
                    }
                    updateSemaphore.signal()
                }
                return
            }

            //mleavy: don't reverse
            if isFillFromBottom {
                if let lastSection = sections.last {
                    context.coordinator.paginationTargetIndexPath = IndexPath(row: lastSection.rows.count - 1, section: sections.count - 1)
                }
            }
            else {
                if let firstSection = sections.first {
                    context.coordinator.paginationTargetIndexPath = IndexPath(row: 0 , section: 0)
                }
            }

            let prevSections = context.coordinator.sections
            let (appliedDeletes, appliedDeletesSwapsAndEdits, deleteOperations, swapOperations, editOperations, insertOperations) = operationsSplit(oldSections: prevSections, newSections: sections)

            // step 1
            // preapare intermediate sections and operations
            //print("1 updateUIView sections:", "\n")
            //print("whole previous:\n", formatSections(prevSections), "\n")
            //print("whole appliedDeletes:\n", formatSections(appliedDeletes), "\n")
            //print("whole appliedDeletesSwapsAndEdits:\n", formatSections(appliedDeletesSwapsAndEdits), "\n")
            //print("whole final sections:\n", formatSections(sections), "\n")

            //print("operations delete:\n", deleteOperations.map { $0.description })
            //print("operations swap:\n", swapOperations.map { $0.description })
            //print("operations edit:\n", editOperations.map { $0.description })
            //print("operations insert:\n", insertOperations.map { $0.description })

            DispatchQueue.main.async {
                tableView.performBatchUpdates {
                    // step 2
                    // delete sections and rows if necessary
                    //print("2 apply delete")
                    context.coordinator.sections = appliedDeletes
                    for operation in deleteOperations {
                        applyOperation(operation, tableView: tableView)
                    }
                } completion: { _ in
                    tableSemaphore.signal()
                    //print("2 finished delete")
                }
            }
            tableSemaphore.wait()

            DispatchQueue.main.async {
                tableView.performBatchUpdates {
                    // step 3
                    // swap places for rows that moved inside the table
                    // (example of how this happens. send two messages: first m1, then m2. if m2 is delivered to server faster, then it should jump above m1 even though it was sent later)
                    //print("3 apply swaps")
                    context.coordinator.sections = appliedDeletesSwapsAndEdits // NOTE: this array already contains necessary edits, but won't be a problem for appplying swaps
                    for operation in swapOperations {
                        applyOperation(operation, tableView: tableView)
                    }
                } completion: { _ in
                    tableSemaphore.signal()
                    //print("3 finished swaps")
                }
            }
            tableSemaphore.wait()

            DispatchQueue.main.async {
                UIView.setAnimationsEnabled(false)
                tableView.performBatchUpdates {
                    // step 4
                    // check only sections that are already in the table for existing rows that changed and apply only them to table's dataSource without animation
                    //print("4 apply edits")
                    context.coordinator.sections = appliedDeletesSwapsAndEdits

                    for operation in editOperations {
                        applyOperation(operation, tableView: tableView)
                    }

                } completion: { _ in
                    tableSemaphore.signal()
                    UIView.setAnimationsEnabled(true)
                    //print("4 finished edits")
                }
            }
            tableSemaphore.wait()

            // mleavy: what is this "if isScrolledToBottom || isScrolledToTop"
            // bs? Inserts never occur unless the view is at either extreme end?
            // how does that make any sense?
            
            //if isScrolledToBottom || isScrolledToTop {
            let always = true
            if always {
                DispatchQueue.main.sync {
                    // step 5
                    // apply the rest of the changes to table's dataSource, i.e. inserts
                    //print("5 apply inserts")
                    context.coordinator.sections = sections
                    
                    //mleavy: better updating, more consistent scroll-to-bottom behavior
                    if isFillFromBottom {
                        context.coordinator.sections = sections

                        tableView.beginUpdates()
                        for operation in insertOperations {
                            applyOperation(operation, tableView: tableView)
                        }
                        tableView.endUpdates()

                        if !isScrollEnabled {
                            tableContentHeight = tableView.contentSize.height
                        }

                        updateSemaphore.signal()
                    }
                    else {
                        tableView.performUpdate {
                            for operation in insertOperations {
                                applyOperation(operation, tableView: tableView)
                            }
                        } completion: {
                            if !isScrollEnabled {
                                tableContentHeight = tableView.contentSize.height
                            }
                            
                            //tableView.performSelector(onMainThread: #selector(tableView.scrollToEnd), with: nil, waitUntilDone: true)
                            
                            updateSemaphore.signal()
                        }
                    }
                }
            } else {
                updateSemaphore.signal()
            }
        }
    }

    // MARK: - Operations

    enum Operation {
        case deleteSection(Int)
        case insertSection(Int)

        case delete(Int, Int) // delete with animation
        case insert(Int, Int) // insert with animation
        case swap(Int, Int, Int) // delete first with animation, then insert it into new position with animation. do not do anything with the second for now
        case edit(Int, Int) // reload the element without animation

        var description: String {
            switch self {
            case .deleteSection(let int):
                return "deleteSection \(int)"
            case .insertSection(let int):
                return "insertSection \(int)"
            case .delete(let int, let int2):
                return "delete section \(int) row \(int2)"
            case .insert(let int, let int2):
                return "insert section \(int) row \(int2)"
            case .swap(let int, let int2, let int3):
                return "swap section \(int) rowFrom \(int2) rowTo \(int3)"
            case .edit(let int, let int2):
                return "edit section \(int) row \(int2)"
            }
        }
    }

    func applyOperation(_ operation: Operation, tableView: UITableView) {
        let animation: UITableView.RowAnimation = .top
        switch operation {
        case .deleteSection(let section):
            tableView.deleteSections([section], with: animation)
        case .insertSection(let section):
            tableView.insertSections([section], with: animation)

        case .delete(let section, let row):
            tableView.deleteRows(at: [IndexPath(row: row, section: section)], with: animation)
        case .insert(let section, let row):
            tableView.insertRows(at: [IndexPath(row: row, section: section)], with: animation)
        case .edit(let section, let row):
            tableView.reloadRows(at: [IndexPath(row: row, section: section)], with: .none)
        case .swap(let section, let rowFrom, let rowTo):
            tableView.deleteRows(at: [IndexPath(row: rowFrom, section: section)], with: animation)
            tableView.insertRows(at: [IndexPath(row: rowTo, section: section)], with: animation)
        }
    }

    func operationsSplit(oldSections: [MessagesSection], newSections: [MessagesSection]) -> ([MessagesSection], [MessagesSection], [Operation], [Operation], [Operation], [Operation]) {
        var appliedDeletes = oldSections // start with old sections, remove rows that need to be deleted
        var appliedDeletesSwapsAndEdits = newSections // take new sections and remove rows that need to be inserted for now, then we'll get array with all the changes except for inserts
        // appliedDeletesSwapsEditsAndInserts == newSection

        var deleteOperations = [Operation]()
        var swapOperations = [Operation]()
        var editOperations = [Operation]()
        var insertOperations = [Operation]()

        // 1 compare sections

        let oldDates = oldSections.map { $0.date }
        let newDates = newSections.map { $0.date }
        let commonDates = Array(Set(oldDates + newDates)).sorted(by: >)
        for date in commonDates {
            let oldIndex = appliedDeletes.firstIndex(where: { $0.date == date } )
            let newIndex = appliedDeletesSwapsAndEdits.firstIndex(where: { $0.date == date } )
            if oldIndex == nil, let newIndex {
                // operationIndex is not the same as newIndex because appliedDeletesSwapsAndEdits is being changed as we go, but to apply changes to UITableView we should have initial index
                if let operationIndex = newSections.firstIndex(where: { $0.date == date } ) {
                    appliedDeletesSwapsAndEdits.remove(at: newIndex)
                    insertOperations.append(.insertSection(operationIndex))
                }
                continue
            }
            if newIndex == nil, let oldIndex {
                if let operationIndex = oldSections.firstIndex(where: { $0.date == date } ) {
                    appliedDeletes.remove(at: oldIndex)
                    deleteOperations.append(.deleteSection(operationIndex))
                }
                continue
            }
            guard let newIndex, let oldIndex else { continue }

            // 2 compare section rows
            // isolate deletes and inserts, and remove them from row arrays, leaving only rows that are in both arrays: 'duplicates'
            // this will allow to compare relative position changes of rows - swaps

            var oldRows = appliedDeletes[oldIndex].rows
            var newRows = appliedDeletesSwapsAndEdits[newIndex].rows
            let oldRowIDs = oldRows.map { $0.id }
            let newRowIDs = newRows.map { $0.id }
            let rowIDsToDelete = oldRowIDs.filter { !newRowIDs.contains($0) }.reversed()
            let rowIDsToInsert = newRowIDs.filter { !oldRowIDs.contains($0) }
            for rowId in rowIDsToDelete {
                if let index = oldRows.firstIndex(where: { $0.id == rowId }) {
                    oldRows.remove(at: index)
                    deleteOperations.append(.delete(oldIndex, index)) // this row was in old section, should not be in final result
                }
            }
            for rowId in rowIDsToInsert {
                if let index = newRows.firstIndex(where: { $0.id == rowId }) {
                    // this row was not in old section, should add it to final result
                    insertOperations.append(.insert(newIndex, index))
                }
            }

            for rowId in rowIDsToInsert {
                if let index = newRows.firstIndex(where: { $0.id == rowId }) {
                    // remove for now, leaving only 'duplicates'
                    newRows.remove(at: index)
                }
            }

            // 3 isolate swaps and edits

            for i in 0..<oldRows.count {
                let oldRow = oldRows[i]
                let newRow = newRows[i]
                if oldRow.id != newRow.id { // a swap: rows in same position are not actually the same rows
                    if let index = newRows.firstIndex(where: { $0.id == oldRow.id }) {
                        if !swapsContain(swaps: swapOperations, section: oldIndex, index: i) ||
                            !swapsContain(swaps: swapOperations, section: oldIndex, index: index) {
                            swapOperations.append(.swap(oldIndex, i, index))
                        }
                    }
                } else if oldRow != newRow { // same ids om same positions but something changed - reload rows without animation
                    editOperations.append(.edit(oldIndex, i))
                }
            }

            // 4 store row changes in sections

            appliedDeletes[oldIndex].rows = oldRows
            appliedDeletesSwapsAndEdits[newIndex].rows = newRows
        }

        return (appliedDeletes, appliedDeletesSwapsAndEdits, deleteOperations, swapOperations, editOperations, insertOperations)
    }

    func swapsContain(swaps: [Operation], section: Int, index: Int) -> Bool {
        swaps.filter {
            if case let .swap(section, rowFrom, rowTo) = $0 {
                return section == section && (rowFrom == index || rowTo == index)
            }
            return false
        }.count > 0
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, inputViewModel: inputViewModel, isScrolledToBottom: $isScrolledToBottom, isScrolledToTop: $isScrolledToTop, messageBuilder: messageBuilder, mainHeaderBuilder: mainHeaderBuilder, headerBuilder: headerBuilder, chatTheme: theme, type: type, showDateHeaders: showDateHeaders, avatarSize: avatarSize, showMessageMenuOnLongPress: showMessageMenuOnLongPress, tapAvatarClosure: tapAvatarClosure, tapReactionClosure: tapReactionClosure, paginationHandler: paginationHandler, messageUseMarkdown: messageUseMarkdown, showMessageTimeView: showMessageTimeView, messageFont: messageFont, sections: sections, ids: ids, mainBackgroundColor: theme.colors.mainBackground, inputManager: inputManager)
    }

    class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {

        @ObservedObject var viewModel: ChatViewModel
        @ObservedObject var inputViewModel: InputViewModel

        @Binding var isScrolledToBottom: Bool
        @Binding var isScrolledToTop: Bool

        let messageBuilder: MessageBuilderClosure?
        let mainHeaderBuilder: (()->AnyView)?
        let headerBuilder: ((Date)->AnyView)?

        let chatTheme: ChatTheme
        let type: ChatType
        let showDateHeaders: Bool
        let avatarSize: CGFloat
        let showMessageMenuOnLongPress: Bool
        let tapAvatarClosure: ChatView.TapAvatarClosure?
        let tapReactionClosure: ReactionTappedClosure?
        let paginationHandler: PaginationHandler?
        let messageUseMarkdown: Bool
        let showMessageTimeView: Bool
        let messageFont: UIFont
        var sections: [MessagesSection] {
            didSet {
                //mleavy: don't reverse
                if isFillFromBottom {
                    if let lastSection = sections.last {
                        paginationTargetIndexPath = IndexPath(row: lastSection.rows.count - 1, section: sections.count - 1)
                    }
                }
                else {
                    if let firstSection = sections.first {
                        paginationTargetIndexPath = IndexPath(row: 0 , section: 0)
                    }
                }
            }
        }
        let ids: [String]
        let mainBackgroundColor: Color
        let inputManager: CustomInputManager
        
        init(viewModel: ChatViewModel, inputViewModel: InputViewModel, isScrolledToBottom: Binding<Bool>, isScrolledToTop: Binding<Bool>, messageBuilder: MessageBuilderClosure?, mainHeaderBuilder: (()->AnyView)?, headerBuilder: ((Date)->AnyView)?, chatTheme: ChatTheme, type: ChatType, showDateHeaders: Bool, avatarSize: CGFloat, showMessageMenuOnLongPress: Bool, tapAvatarClosure: ChatView.TapAvatarClosure?, tapReactionClosure: ReactionTappedClosure?, paginationHandler: PaginationHandler?, messageUseMarkdown: Bool, showMessageTimeView: Bool, messageFont: UIFont, sections: [MessagesSection], ids: [String], mainBackgroundColor: Color, paginationTargetIndexPath: IndexPath? = nil, inputManager: CustomInputManager) {
            self.viewModel = viewModel
            self.inputViewModel = inputViewModel
            self._isScrolledToBottom = isScrolledToBottom
            self._isScrolledToTop = isScrolledToTop
            self.messageBuilder = messageBuilder
            self.mainHeaderBuilder = mainHeaderBuilder
            self.headerBuilder = headerBuilder
            self.chatTheme = chatTheme
            self.type = type
            self.showDateHeaders = showDateHeaders
            self.avatarSize = avatarSize
            self.showMessageMenuOnLongPress = showMessageMenuOnLongPress
            self.tapAvatarClosure = tapAvatarClosure
            self.tapReactionClosure = tapReactionClosure
            self.paginationHandler = paginationHandler
            self.messageUseMarkdown = messageUseMarkdown
            self.showMessageTimeView = showMessageTimeView
            self.messageFont = messageFont
            self.sections = sections
            self.ids = ids
            self.mainBackgroundColor = mainBackgroundColor
            self.paginationTargetIndexPath = paginationTargetIndexPath
            self.inputManager = inputManager
        }

        /// call pagination handler when this row is reached
        /// without this there is a bug: during new cells insertion willDisplay is called one extra time for the cell which used to be the last one while it is being updated (its position in group is changed from first to middle)
        var paginationTargetIndexPath: IndexPath?
        
        var isScrolledNearBottom: Bool = true

        func numberOfSections(in tableView: UITableView) -> Int {
            return sections.count
        }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            sections[section].rows.count
        }

        //mleavy - NO reverse when filling top to bottom
        func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
            if isFillFromBottom {
                if type == .comments {
                    return sectionHeaderView(section)
                }
                return nil
            }
            else {
                return sectionHeaderView(section)
            }
        }

        //mleavy - NO reverse when filling top to bottom
        func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
            if isFillFromBottom {
                if type == .conversation {
                    return sectionHeaderView(section)
                }
                return nil
            }
            else {
                return nil
            }
        }

        //mleavy - NO reverse when filling top to bottom
        func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
            if !showDateHeaders && (section != 0 || mainHeaderBuilder == nil) {
                return 0.1
            }
            return UITableView.automaticDimension
        }

        //mleavy - NO reverse when filling top to bottom
        func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
            if isFillFromBottom {
                if !showDateHeaders && (section != 0 || mainHeaderBuilder == nil) {
                    return 0.1
                }
                return type == .conversation ? UITableView.automaticDimension : UITableView.automaticDimension
            }
            else {
                if !showDateHeaders && (section != 0 || mainHeaderBuilder == nil) {
                    return 0.1
                }
                return 0.1
            }
        }

        func sectionHeaderView(_ section: Int) -> UIView? {
            if !showDateHeaders && (section != 0 || mainHeaderBuilder == nil) {
                return nil
            }

            //mleavy - NO rotation when filling top to bottom
            let header = UIHostingController(rootView:
                sectionHeaderViewBuilder(section)
                .rotationEffect(Angle(degrees: (type == .conversation ? (isFillFromBottom ? 180 : 0) : 0)))
                .scaleEffect(CGSize(width: (chatTheme.extensions.showsScrollIndicator ? -1 : 1), height: 1))
            ).view
            header?.backgroundColor = UIColor(chatTheme.colors.mainBackground)
            return header
        }

        @ViewBuilder
        func sectionHeaderViewBuilder(_ section: Int) -> some View {
            if let mainHeaderBuilder, section == 0 {
                VStack(spacing: 0) {
                    mainHeaderBuilder()
                    dateViewBuilder(section)
                }
            } else {
                dateViewBuilder(section)
            }
        }

        @ViewBuilder
        func dateViewBuilder(_ section: Int) -> some View {
            if showDateHeaders {
                if let headerBuilder {
                    headerBuilder(sections[section].date)
                } else {
                    VStack {
                        Text(sections[section].formattedDate)
                            .font(.system(size: 12))
                            .padding(.top, -6)
                            .padding(.bottom, 5)
                            .foregroundColor(.gray)
                    }
                    .padding(0)
                }
            }
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

            let tableViewCell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            tableViewCell.selectionStyle = .none
            tableViewCell.backgroundColor = UIColor(mainBackgroundColor)

            let row = sections[indexPath.section].rows[indexPath.row]
            tableViewCell.contentConfiguration = UIHostingConfiguration {
                ChatMessageView(viewModel: viewModel, messageBuilder: messageBuilder, row: row, chatType: type, avatarSize: avatarSize, tapAvatarClosure: tapAvatarClosure, tapReactionClosure: tapReactionClosure, messageUseMarkdown: messageUseMarkdown, isDisplayingMessageMenu: false, showMessageTimeView: showMessageTimeView, messageFont: messageFont)
                    .transition(.scale)
                    .background(MessageMenuPreferenceViewSetter(id: row.id))
                    //mleavy - NO rotation when filling top to bottom
                    .rotationEffect(Angle(degrees: (type == .conversation ? (isFillFromBottom ? 180 : 0) : 0)))
                    .scaleEffect(CGSize(width: (chatTheme.extensions.showsScrollIndicator ? -1 : 1), height: 1))
                    .onTapGesture { }
                    .applyIf(showMessageMenuOnLongPress) {
                        $0.onLongPressGesture {
                            if (tableViewCell.frame.origin.y - tableViewCell.frame.height > tableView.contentOffset.y) {
                                tableView.scrollRectToVisible(tableViewCell.frame, animated: false)
                            }
                            self.viewModel.messageMenuRow = row
                        }
                    }
            }
            .minSize(width: 0, height: 0)
            .margins(.all, 0)

            return tableViewCell
        }
        
        func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
            print("section = \(indexPath.section), row = \(indexPath.row)")
            guard let paginationHandler = self.paginationHandler, let paginationTargetIndexPath, indexPath == paginationTargetIndexPath else {
                
                let row = sections[indexPath.section].rows[indexPath.row]
                if row.message.isAnimated {
                    row.message.isAnimated = false
                    
                    guard isScrolledNearBottom else { return }
                    
                    if row.message.user.isCurrentUser {
                        
                        let inputContainer = inputManager.inputView
                        if let tableContainer = inputContainer.superview {
                            let cellPoint = cell.convert(cell.frame, to: tableContainer)
                            let inputPoint = inputManager.inputView.textView.convert(inputManager.inputView.textView.frame, to: tableContainer)
                            
                            let diffX = inputPoint.minX - cellPoint.midX
                            let diffY = cellPoint.minY - inputPoint.minY
                            
                            print("translating by \(diffX) and \(diffY)")
                            
                            cell.transform = .init(scaleX: 0.3, y: 0.3).concatenating(.init(translationX: diffX, y: diffY))
                            cell.layer.opacity = 0.65
                        }
                        
                        UIView.animate(withDuration: 0.4) {
                            cell.layer.opacity = 1
                            cell.transform = .identity
                        }
                    }
                    else {
                        cell.layer.opacity = 0
                        cell.transform = .init(scaleX: 0, y: 0).concatenating(.init(translationX: -cell.frame.width, y: 0))
                        
                        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut) {
                            cell.layer.opacity = 1
                            cell.transform = .identity
                        }
                    }
                }
                
                return
                
            }

            let row = self.sections[indexPath.section].rows[indexPath.row]
            Task.detached {
                await paginationHandler.handleClosure(row.message)
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            isScrolledToBottom = scrollView.contentOffset.y <= 0
            isScrolledToTop = scrollView.contentOffset.y >= scrollView.contentSize.height - scrollView.frame.height - 1
            isScrolledNearBottom = scrollView.contentOffset.y <= 50
        }
    }

    func formatRow(_ row: MessageRow) -> String {
        if let status = row.message.status {
            return String("id: \(row.id) text: \(row.message.text) status: \(status) date: \(row.message.createdAt) position: \(row.positionInUserGroup) trigger: \(row.message.triggerRedraw)")
        }
        return ""
    }

    func formatSections(_ sections: [MessagesSection]) -> String {
        var res = "{\n"
        for section in sections.reversed() {
            res += String("\t{\n")
            for row in section.rows {
                res += String("\t\t\(formatRow(row))\n")
            }
            res += String("\t}\n")
        }
        res += String("}")
        return res
    }
}

//mleavy - table view updating helpers
extension UITableView {

    /// Perform a series of method calls that insert, delete, or select rows and sections of the table view.
    /// This is equivalent to a beginUpdates() / endUpdates() sequence,
    /// with a completion closure when the animation is finished.
    /// Parameter update: the update operation to perform on the tableView.
    /// Parameter completion: the completion closure to be executed when the animation is completed.
   
    func performUpdate(_ update: () -> Void, completion: (()->Void)?) {
    
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)

        // Table View update on row / section
        beginUpdates()
        update()
        endUpdates()
    
        CATransaction.commit()
    }

    @objc public func scrollToEnd() {
        scrollRectToVisible(.init(x: 0,
                            y: contentSize.height - 1,
                            width: frame.size.width,
                            height: 1), animated: true)
    }
}
