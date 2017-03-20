//
//  ObservableArray.swift
//  ObservableArray
//
//  Created by Safx Developer on 2015/02/19.
//  Copyright (c) 2016 Safx Developers. All rights reserved.
//

import Foundation
import RxSwift

public struct ArrayChangeEvent {
    public let insertedIndices: [Int]
    public let deletedIndices: [Int]
    public let updatedIndices: [Int]

    fileprivate init(inserted: [Int] = [], deleted: [Int] = [], updated: [Int] = []) {
        assert(inserted.count + deleted.count + updated.count > 0)
        self.insertedIndices = inserted
        self.deletedIndices = deleted
        self.updatedIndices = updated
    }
}

public struct ArrayChange<Element> {
    public let indexes: [Int]
    public let elements: [Element]
    
    public init(indexes: [Int], elements: [Element] = []) {
        assert(indexes.count > 0)
        self.indexes = indexes
        self.elements = elements
    }
    
    public init(withElements elements: [Element], at: Int) {
        assert(elements.count > 0)
        self.elements = elements
        self.indexes = [at]
    }
}

public struct ObservableArray<Element>: ExpressibleByArrayLiteral {
    public typealias EventType = ArrayChangeEvent

    internal var eventSubject: PublishSubject<EventType>!
    internal var elementsSubject: BehaviorSubject<[Element]>!
    internal var elements: [Element]

    public init() {
        self.elements = []
    }

    public init(count:Int, repeatedValue: Element) {
        self.elements = Array(repeating: repeatedValue, count: count)
    }

    public init<S : Sequence>(_ s: S) where S.Iterator.Element == Element {
        self.elements = Array(s)
    }

    public init(arrayLiteral elements: Element...) {
        self.elements = elements
    }
}

extension ObservableArray {
    public mutating func rx_elements() -> Observable<[Element]> {
        if elementsSubject == nil {
            self.elementsSubject = BehaviorSubject<[Element]>(value: self.elements)
        }
        return elementsSubject
    }

    public mutating func rx_events() -> Observable<EventType> {
        if eventSubject == nil {
            self.eventSubject = PublishSubject<EventType>()
        }
        return eventSubject
    }

    fileprivate func arrayDidChange(_ event: EventType) {
        elementsSubject?.onNext(elements)
        eventSubject?.onNext(event)
    }
}

extension ObservableArray: Collection {
    public var capacity: Int {
        return elements.capacity
    }

    /*public var count: Int {
        return elements.count
    }*/

    public var startIndex: Int {
        return elements.startIndex
    }

    public var endIndex: Int {
        return elements.endIndex
    }

    public func index(after i: Int) -> Int {
        return elements.index(after: i)
    }
}

extension ObservableArray: MutableCollection {
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        elements.reserveCapacity(minimumCapacity)
    }

    public mutating func append(_ newElement: Element) {
        elements.append(newElement)
        arrayDidChange(ArrayChangeEvent(inserted: [elements.count - 1]))
    }

    public mutating func append<S : Sequence>(contentsOf newElements: S) where S.Iterator.Element == Element {
        let end = elements.count
        elements.append(contentsOf: newElements)
        guard end != elements.count else {
            return
        }
        arrayDidChange(ArrayChangeEvent(inserted: Array(end..<elements.count)))
    }

    public mutating func appendContentsOf<C : Collection>(_ newElements: C) where C.Iterator.Element == Element {
        guard !newElements.isEmpty else {
            return
        }
        let end = elements.count
        elements.append(contentsOf: newElements)
        arrayDidChange(ArrayChangeEvent(inserted: Array(end..<elements.count)))
    }

    public mutating func removeLast() -> Element {
        let e = elements.removeLast()
        arrayDidChange(ArrayChangeEvent(deleted: [elements.count]))
        return e
    }

    public mutating func insert(_ newElement: Element, at i: Int) {
        elements.insert(newElement, at: i)
        arrayDidChange(ArrayChangeEvent(inserted: [i]))
    }

    public mutating func remove(at index: Int) -> Element {
        let e = elements.remove(at: index)
        arrayDidChange(ArrayChangeEvent(deleted: [index]))
        return e
    }

    public mutating func removeAll(_ keepCapacity: Bool = false) {
        guard !elements.isEmpty else {
            return
        }
        let es = elements
        elements.removeAll(keepingCapacity: keepCapacity)
        arrayDidChange(ArrayChangeEvent(deleted: Array(0..<es.count)))
    }

    public mutating func insertContentsOf(_ newElements: [Element], atIndex i: Int) {
        guard !newElements.isEmpty else {
            return
        }
        elements.insert(contentsOf: newElements, at: i)
        arrayDidChange(ArrayChangeEvent(inserted: Array(i..<i + newElements.count)))
    }

    public mutating func popLast() -> Element? {
        let e = elements.popLast()
        if e != nil {
            arrayDidChange(ArrayChangeEvent(deleted: [elements.count]))
        }
        return e
    }
    
    
    /// Update the array in one shot
    /// 
    /// ##Note##
    ///
    /// Order of things :
    /// * Delete
    /// * Add
    /// * Update
    ///
    /// You should give the indexes of update and add as there are for the original array. It means that if you add at 1 and delete at 0 the add will be at 0.
    ///
    /// - Parameters:
    ///   - updated: description on indexes to update with corresponding Element
    ///   - deleted: description of indexes to delete
    ///   - added: description of indexes to add with corresponding elements
    public mutating func change(updated: ArrayChange<Element>?, deleted: ArrayChange<Element>?, added: ArrayChange<Element>?) {
        
        let updateIndexes: [Int] = updated?.indexes ?? []
        var deleteIndexes: [Int] = []
        var tmpAddIndexes: [Int] = added?.indexes ?? []
        var addIndexes: [Int] = []
        
        if let updated = updated {
            for i in 0..<updated.indexes.count {
                elements[updated.indexes[i]] = updated.elements[i]
            }
        }
        
        if let deleted = deleted {
            deleteIndexes = deleted.indexes
            for index in deleted.indexes.sorted(by: { $0 > $1 }) {
                elements.remove(at: index)
                tmpAddIndexes = tmpAddIndexes.map({ ($0 > index) ? $0-1 : $0 })
            }
        }
        
        if let added = added {
            
            let originalCount = elements.count
            
            if tmpAddIndexes.count == 1 && added.elements.count > 1 {
                addIndexes.append(contentsOf: tmpAddIndexes[0]..<tmpAddIndexes[0]+added.elements.count)
                elements.insert(contentsOf: added.elements, at: tmpAddIndexes[0])
            } else {
                var count = 0
                for index in tmpAddIndexes.sorted(by: {$0 < $1}) {
                    
                    let i = tmpAddIndexes.index(of: index)!
                    if index+count < elements.count {
                        elements.insert(added.elements[i], at: index+count)
                        addIndexes.append(index+count)
                    }else {
                        addIndexes.append(elements.count)
                        elements.append(added.elements[i])
                    }
                    
                    if index < originalCount {
                        count += 1
                    }
                }
            }
        }
        
        if updateIndexes.count+deleteIndexes.count+addIndexes.count > 0 {
            arrayDidChange(ArrayChangeEvent(inserted: addIndexes, deleted: deleteIndexes, updated: updateIndexes))
        }
    }
}

extension ObservableArray: RangeReplaceableCollection {
    public mutating func replaceSubrange<C : Collection>(_ subRange: Range<Int>, with newCollection: C) where C.Iterator.Element == Element {
        let oldCount = elements.count
        elements.replaceSubrange(subRange, with: newCollection)
        let first = subRange.lowerBound
        let newCount = elements.count
        let end = first + (newCount - oldCount) + subRange.count
        arrayDidChange(ArrayChangeEvent(inserted: Array(first..<end),
                                        deleted: Array(subRange.lowerBound..<subRange.upperBound)))
    }
}

extension ObservableArray: CustomDebugStringConvertible {
    public var description: String {
        return elements.description
    }
}

extension ObservableArray: CustomStringConvertible {
    public var debugDescription: String {
        return elements.debugDescription
    }
}

extension ObservableArray: Sequence {

    public subscript(index: Int) -> Element {
        get {
            return elements[index]
        }
        set {
            elements[index] = newValue
            if index == elements.count {
                arrayDidChange(ArrayChangeEvent(inserted: [index]))
            } else {
                arrayDidChange(ArrayChangeEvent(updated: [index]))
            }
        }
    }

    public subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        get {
            return elements[bounds]
        }
        set {
            elements[bounds] = newValue
            let first = bounds.lowerBound
            arrayDidChange(ArrayChangeEvent(inserted: Array(first..<first + newValue.count),
                                            deleted: Array(bounds.lowerBound..<bounds.upperBound)))
        }
    }
}
