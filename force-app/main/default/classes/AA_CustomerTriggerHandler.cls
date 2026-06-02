public with sharing class AA_CustomerTriggerHandler {
    
    public static void handleBeforeInsertUpdate(List<AA_Customer__c> newRecords, Map<Id, AA_Customer__c> oldMap, Boolean isInsert, Boolean isUpdate) {
        
        List<AA_Customer__c> recordsToProcess = new List<AA_Customer__c>();
        Set<Id> businessIds = new Set<Id>();
        
        for (AA_Customer__c record : newRecords) {
            Boolean needsUpdate = false;
            
            if (isInsert) {
                needsUpdate = true;
            } else if (isUpdate) {
                AA_Customer__c oldRecord = oldMap.get(record.Id);
                if (record.Name != oldRecord.Name || 
                    record.First_Name__c != oldRecord.First_Name__c || 
                    record.Last_Name__c != oldRecord.Last_Name__c || 
                    record.Business__c != oldRecord.Business__c) {
                    needsUpdate = true;
                }
            }
            
            if (needsUpdate && record.Business__c != null) {
                recordsToProcess.add(record);
                businessIds.add(record.Business__c);
            }
        }
        
        if (!recordsToProcess.isEmpty()) {
            Map<Id, AA_Business__c> businessMap = new Map<Id, AA_Business__c>([
                SELECT Id, Name FROM AA_Business__c WHERE Id IN :businessIds
            ]);
            
            for (AA_Customer__c record : recordsToProcess) {
                AA_Business__c business = businessMap.get(record.Business__c);
                if (business != null) {
                    String firstName = record.First_Name__c != null ? record.First_Name__c : '';
                    String lastName = record.Last_Name__c != null ? record.Last_Name__c : '';
                    
                    String newName = firstName;
                    if (String.isNotBlank(lastName)) {
                        newName += (String.isNotBlank(newName) ? ' ' : '') + lastName;
                    }
                    if (String.isNotBlank(business.Name)) {
                        newName += (String.isNotBlank(newName) ? ' - ' : '') + business.Name;
                    }
                    
                    record.Name = newName.abbreviate(75);
                }
            }
        }
    }
}