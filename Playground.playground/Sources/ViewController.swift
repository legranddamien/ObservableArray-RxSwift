import Foundation
import UIKit
import RxSwift
import RxCocoa
import ObservableArray

extension UIColor {
    
    static var random: UIColor {
        get {
            let randomRed:CGFloat = CGFloat(drand48())
            let randomGreen:CGFloat = CGFloat(drand48())
            let randomBlue:CGFloat = CGFloat(drand48())
            return UIColor(red: randomRed, green: randomGreen, blue: randomBlue, alpha: 1.0)
        }
    }
}

class Item {
    
    var color = UIColor.random
    
    func update() {
        self.color = UIColor.random
    }
    
}

func randomNumber<T : SignedInteger>(inRange range: ClosedRange<T> = 1...6) -> T {
    let length = (range.upperBound - range.lowerBound + 1).toIntMax()
    let value = arc4random().toIntMax() % length + range.lowerBound.toIntMax()
    return T(value)
}

extension UICollectionView {
    
    public func rx_autoUpdater(source: Observable<ArrayChangeEvent>) -> Disposable {
        
        return source.observeOn(MainScheduler.instance).subscribe(onNext: { (changes) in
            
            let number = self.numberOfItems(inSection: 0)
            
            func toIndexSet(array: [Int]) -> [IndexPath] {
                return array.map { IndexPath(item: $0, section: 0) }
            }
            
            print("--- Auto Updater ---")
            print("deleted : \(changes.deletedIndices)")
            print("inserted : \(changes.insertedIndices)")
            print("updated : \(changes.updatedIndices)")
            
            self.performBatchUpdates({ 
                
                if changes.deletedIndices.count > 0 {
                    self.deleteItems(at: toIndexSet(array: changes.deletedIndices))
                }
                
                if changes.insertedIndices.count > 0 {
                    self.insertItems(at: toIndexSet(array: changes.insertedIndices))
                }
                
                if changes.updatedIndices.count > 0 {
                    self.reloadItems(at: toIndexSet(array: changes.updatedIndices))
                }
                
            }, completion: nil)
            
        })
    }
}


public class ViewController : UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    // MARK: Parameters
    
    static let CellIdentifier = "Cell"
    
    var items: ObservableArray<Item> = []
    let disposeBag = DisposeBag()
    var timer: Timer? = nil
    
    // MARK: Init
    
    public init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        super.init(collectionViewLayout: layout)
        
        var items: [Item] = []
        for _ in 0...30 {
            items.append(Item())
        }
        
        self.items.appendContentsOf(items)
        
        if let collectionView = self.collectionView {
            self.items
            .rx_events()
            .observeOn(MainScheduler.instance)
            .bindTo(collectionView.rx_autoUpdater)
            .addDisposableTo(disposeBag)
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: View Life Cycle
    
    override public func viewDidLoad() {
        
        super.viewDidLoad()
        self.collectionView?.register(UICollectionViewCell.self, forCellWithReuseIdentifier: ViewController.CellIdentifier)
        self.collectionView?.alwaysBounceVertical = true
        
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        self.startTimer()
    }
    
    // MARK: Actions
    
    @objc func refreshed() {
        self.reload()
    }
    
    // MARK: Private Methods
    
    func startTimer() {
        self.timer = Timer.scheduledTimer(timeInterval: 0.6, target: self, selector: #selector(refreshed), userInfo: nil, repeats: false)
    }
    
    func reload() {
        
        print("------------------------")
        print("------------------------")
        
        var currentCount = self.items.count
        
        print("Number of elements : \(currentCount)")
        
        var updated: ArrayChange<Item>? = nil
        var added: ArrayChange<Item>? = nil
        var removed: ArrayChange<Item>? = nil
    
        var nbToUpdate: Int = randomNumber(inRange: 0...self.items.count-1)
        if nbToUpdate > 0 {
            
            if nbToUpdate > 10 {
                nbToUpdate = 10
            }
            
            var updatedIndexes: [Int] = []
            var elementsUpdated: [Item] = []
            
            for _ in 0..<nbToUpdate {
                let index = randomNumber(inRange: 0...self.items.count-1)
                if !updatedIndexes.contains(index) {
                    updatedIndexes.append(index)
                    self.items[index].update()
                    elementsUpdated.append(self.items[index])
                }
            }
            
            print("Indexes to update : \(updatedIndexes)")
            
            if updatedIndexes.count > 0 {
                updated = ArrayChange<Item>(indexes: updatedIndexes, elements: elementsUpdated)
            }
        }
        
        let nbToAdd: Int = randomNumber(inRange: 0...10)
        if nbToAdd > 0 {
            
            var addedIndexes: [Int] = []
            var elementsToAdd: [Item] = []
            
            for _ in 0..<nbToAdd {
                
                var index = randomNumber(inRange: 0...currentCount)
                let uIndexes = updated?.indexes ?? []
                while uIndexes.contains(index) || addedIndexes.contains(index) {
                    index = randomNumber(inRange: 0...currentCount)
                }
                
                currentCount += 1
                
                addedIndexes.append(index)
                elementsToAdd.append(Item())
            }
            
            print("Indexes to add : \(addedIndexes)")
            
            added = ArrayChange<Item>(indexes: addedIndexes, elements: elementsToAdd)
        }
        
        var indexesAbleToRemove : [Int] = []
        for i in 0..<self.items.count {
            if updated == nil || !updated!.indexes.contains(i) {
                indexesAbleToRemove.append(i)
            }
        }
        if indexesAbleToRemove.count > 0 {
            var nbToDelete: Int = randomNumber(inRange: 0...indexesAbleToRemove.count-1)
            if nbToDelete > 0 {
                
                if nbToDelete > 20 {
                    nbToDelete = 20
                }
                
                var removedIndexes: [Int] = []
                
                for _ in 0..<nbToDelete {
                    
                    let index = indexesAbleToRemove[randomNumber(inRange: 0...indexesAbleToRemove.count-1)]
                    indexesAbleToRemove.remove(at: indexesAbleToRemove.index(of: index)!)
                    let aIndexes = added?.indexes ?? []
                    
                    if !aIndexes.contains(index) {
                        currentCount -= 1
                        removedIndexes.append(index)
                    }
                }
                
                print("Indexes to remove : \(removedIndexes)")
                
                if removedIndexes.count > 0 {
                    removed = ArrayChange<Item>(indexes: removedIndexes)
                }
            }
        }
        
        if updated != nil || added != nil || removed != nil {
            self.items.change(updated: updated, deleted: removed, added: added)
        }
        
        self.startTimer()
    }
    
    // MARK: UICollectionViewDataSource
    
    public override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ViewController.CellIdentifier, for: indexPath)
        
        cell.backgroundColor = items[indexPath.item].color
        
        return cell
        
    }
    
    // MARK: UICollectionViewDelegateFlowLayout
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.size.width / 6.0, height: collectionView.bounds.size.width / 6.0)
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }
}
