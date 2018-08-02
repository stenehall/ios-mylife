//
//  HealthKitInterface.swift
//  mylife
//
//  Created by Johan Stenehall on 2018-08-01.
//  Copyright © 2018 Johan Stenehall. All rights reserved.
//

import Foundation

import HealthKit

class HealthKitInterface
{
    let healthKitDataStore: HKHealthStore?
    
    let steps = NSSet(object: HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!)
    
    init() {
        if HKHealthStore.isHealthDataAvailable() {
            self.healthKitDataStore = HKHealthStore()
            
            healthKitDataStore?.requestAuthorization(toShare: nil, read: steps as? Set<HKObjectType>) { (success, error) -> Void in
                
            }
        }
            
        else {
            self.healthKitDataStore = nil
        }
    }
    
    func readGenderType() -> Void {
        do {
            let genderType = try self.healthKitDataStore?.biologicalSex()
            
            if genderType?.biologicalSex == .female {
                print("Gender is female.")
            }
            else if genderType?.biologicalSex == .male {
                print("Gender is male.")
            }
            else {
                print("Gender is unspecified.")
            }
            
        }
        catch {
            print("Error looking up gender.")
        }
        
    }
    
    func getTodaysSteps(completion: @escaping (Int) -> Void) {
        let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepsQuantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0)
                return
            }
            completion(Int(sum.doubleValue(for: HKUnit.count())))
        }
        
        self.healthKitDataStore?.execute(query)
    }
    
}

