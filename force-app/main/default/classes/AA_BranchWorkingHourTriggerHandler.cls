public with sharing class AA_BranchWorkingHourTriggerHandler {
    
    public static void handleBeforeInsertUpdate(List<AA_Branch_Working_Hour__c> newRecords, Map<Id, AA_Branch_Working_Hour__c> oldMap, Boolean isInsert, Boolean isUpdate) {
        
        List<AA_Branch_Working_Hour__c> recordsToProcess = new List<AA_Branch_Working_Hour__c>();
        Set<Id> branchIds = new Set<Id>();
        
        for (AA_Branch_Working_Hour__c record : newRecords) {
            Boolean needsUpdate = false;
            
            if (isInsert) {
                needsUpdate = true;
            } else if (isUpdate) {
                AA_Branch_Working_Hour__c oldRecord = oldMap.get(record.Id);
                if (record.Name != oldRecord.Name || 
                    record.Day_Of_Week__c != oldRecord.Day_Of_Week__c || 
                    record.Business_Branch__c != oldRecord.Business_Branch__c) {
                    needsUpdate = true;
                }
            }
            
            if (needsUpdate && record.Business_Branch__c != null) {
                recordsToProcess.add(record);
                branchIds.add(record.Business_Branch__c);
            }
        }
        
        if (!recordsToProcess.isEmpty()) {
            Map<Id, AA_Business_Branch__c> branchMap = new Map<Id, AA_Business_Branch__c>([
                SELECT Id, Name FROM AA_Business_Branch__c WHERE Id IN :branchIds
            ]);
            
            for (AA_Branch_Working_Hour__c record : recordsToProcess) {
                AA_Business_Branch__c branch = branchMap.get(record.Business_Branch__c);
                if (branch != null) {
                    String dayOfWeek = record.Day_Of_Week__c != null ? record.Day_Of_Week__c : '';
                    
                    String newName = dayOfWeek;
                    if (String.isNotBlank(branch.Name)) {
                        newName += (String.isNotBlank(newName) ? ' - ' : '') + branch.Name;
                    }
                    
                    record.Name = newName.abbreviate(75);
                }
            }
        }
    }
}
