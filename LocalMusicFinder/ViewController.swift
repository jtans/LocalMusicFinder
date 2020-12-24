//
//  ViewController.swift
//  LocalMusicFinder
//
//  Created by 谭圣 on 2020/12/24.
//

import Cocoa
import RxSwift
import RxCocoa

class ViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
    
    class ObservingClass: NSObject, NSFilePresenter {
        var urlChangeSubject = BehaviorRelay<NSURL?>(value: nil)
        var presentedItemURL: URL?
        lazy var presentedItemOperationQueue = OperationQueue.main
        
        
        private func presentedSubitemDidChangeAtURL(url: NSURL) {
            urlChangeSubject.accept(url)
        }
        
        func presentedItemDidChange() {
            urlChangeSubject.accept(nil)
        }
    }

    private let disposeBag = DisposeBag()
    
    @IBOutlet weak var outlineView: NSOutlineView!
    
    @IBOutlet weak var btnChooseDir: NSButton!
    
    @IBOutlet weak var tfChooseDir: NSTextField!
    
    @IBOutlet weak var searchCtrl: NSSearchField!
    
    let fileListener = ObservingClass()
    
    var dir = BehaviorRelay<String>(value: NSHomeDirectory())
    var files = BehaviorRelay<[String]>(value: [])
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        btnChooseDir.rx.tap.subscribe(onNext: {
            let dialog = NSOpenPanel();

            dialog.title                   = "Choose a folder";
            dialog.showsResizeIndicator    = true;
            dialog.showsHiddenFiles        = true;
            dialog.allowsMultipleSelection = false;
            dialog.canChooseDirectories = true;

            if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
                let result = dialog.url // Pathname of the file

                if (result != nil) {
                    let path: String = result!.path
                    self.dir.accept(path)
                }
                
            } else {
                // User clicked on "Cancel"
                return
            }
        }).disposed(by: disposeBag)
        
        dir.asDriver().drive(tfChooseDir.rx.text).disposed(by: disposeBag)
        
        files.subscribe(onNext: { _ in
            self.outlineView.reloadData()
        }).disposed(by: disposeBag)
        
        Observable.combineLatest(dir.asObservable(), searchCtrl.rx.text.asObservable().distinctUntilChanged().debounce(RxTimeInterval.seconds(Int(0.5)), scheduler: MainScheduler.instance), fileListener.urlChangeSubject.asObservable()).subscribe(onNext: { (dir, keyword, url) in
            guard dir.count > 0 else {
                return
            }
            var files = self.contents(dir: dir)
            if let kw = keyword, kw.count > 0 {
                files = files.filter {
                   return $0.contains(kw)
                }
            }
            self.files.accept(files)
        }).disposed(by: disposeBag)
        
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.reloadData()
    }

    func contents(dir: String) -> [String] {
        guard let paths = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
        return paths
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    // You must give each row a unique identifier, referred to as `item` by the outline view
    //   * For top-level rows, we use the values in the `keys` array
    //   * For the hobbies sub-rows, we label them as ("hobbies", 0), ("hobbies", 1), ...
    //     The integer is the index in the hobbies array
    //
    // item == nil means it's the "root" row of the outline view, which is not visible
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return files.value[index]
    }
    
    // Tell how many children each row has:
    //    * The root row has 5 children: name, age, birthPlace, birthDate, hobbies
    //    * The hobbies row has how ever many hobbies there are
    //    * The other rows have no children
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return files.value.count
    }
    
    // Tell whether the row is expandable. The only expandable row is the Hobbies row
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
    
    // Set the text for each row
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let columnIdentifier = tableColumn?.identifier.rawValue else {
            return nil
        }
        
        var text = item as? String ?? ""
        
//        let cellIdentifier = NSUserInterfaceItemIdentifier("outlineViewCell")
//        let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as! NSTableCellView
//        cell.textField!.stringValue = text ?? ""
        
        let label = NSTextField(string: text)
        return label
    }
}

