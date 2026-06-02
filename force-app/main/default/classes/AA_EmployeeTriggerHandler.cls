public with sharing class AA_EmployeeTriggerHandler {
    
    public static void handleBeforeInsertUpdate(List<AA_Employee__c> newRecords, Map<Id, AA_Employee__c> oldMap, Boolean isInsert, Boolean isUpdate) {
        
        List<AA_Employee__c> recordsToProcess = new List<AA_Employee__c>();
        Set<Id> branchIds = new Set<Id>();
        
        for (AA_Employee__c record : newRecords) {
            Boolean needsUpdate = false;
            
            if (isInsert) {
                needsUpdate = true;
            } else if (isUpdate) {
                AA_Employee__c oldRecord = oldMap.get(record.Id);
                if (record.Name != oldRecord.Name || 
                    record.First_Name__c != oldRecord.First_Name__c || 
                    record.Last_Name__c != oldRecord.Last_Name__c || 
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
            
            for (AA_Employee__c record : recordsToProcess) {
                AA_Business_Branch__c branch = branchMap.get(record.Business_Branch__c);
                if (branch != null) {
                    String firstName = record.First_Name__c != null ? record.First_Name__c : '';
                    String lastName = record.Last_Name__c != null ? record.Last_Name__c : '';
                    
                    String newName = firstName;
                    if (String.isNotBlank(lastName)) {
                        newName += (String.isNotBlank(newName) ? ' ' : '') + lastName;
                    }
                    if (String.isNotBlank(branch.Name)) {
                        newName += (String.isNotBlank(newName) ? ' - ' : '') + branch.Name;
                    }
                    
                    record.Name = newName.abbreviate(75);
                }
            }
        }
    }
}