public with sharing class AA_ServiceTriggerHandler {
    
    public static void handleBeforeInsertUpdate(List<AA_Service__c> newRecords, Map<Id, AA_Service__c> oldMap, Boolean isInsert, Boolean isUpdate) {
        
        List<AA_Service__c> recordsToProcess = new List<AA_Service__c>();
        Set<Id> branchIds = new Set<Id>();
        
        for (AA_Service__c record : newRecords) {
            Boolean needsUpdate = false;
            
            if (isInsert) {
                needsUpdate = true;
            } else if (isUpdate) {
                AA_Service__c oldRecord = oldMap.get(record.Id);
                if (record.Name != oldRecord.Name || 
                    record.Display_Name__c != oldRecord.Display_Name__c || 
                    record.Business_Branch__c != oldRecord.Business_Branch__c ||
                    record.Is_Active__c != oldRecord.Is_Active__c) {
                    needsUpdate = true;
                }
            }
            
            if (needsUpdate && record.Business_Branch__c != null) {
                recordsToProcess.add(record);
                branchIds.add(record.Business_Branch__c);
            } else if (needsUpdate && record.Business_Branch__c == null) {
                // If there's no branch, we still might need to append/remove the suffix
                if (record.Is_Active__c == false) {
                    if (record.Name != null && !record.Name.endsWith(' - Inactive')) {
                        record.Name = (record.Name + ' - Inactive').abbreviate(80);
                    }
                } else {
                    if (record.Name != null && record.Name.endsWith(' - Inactive')) {
                        record.Name = record.Name.removeEnd(' - Inactive').trim();
                    }
                }
            }
        }
        
        if (!recordsToProcess.isEmpty()) {
            Map<Id, AA_Business_Branch__c> branchMap = new Map<Id, AA_Business_Branch__c>([
                SELECT Id, Name FROM AA_Business_Branch__c WHERE Id IN :branchIds
            ]);
            
            for (AA_Service__c record : recordsToProcess) {
                AA_Business_Branch__c branch = branchMap.get(record.Business_Branch__c);
                if (branch != null) {
                    String displayName = record.Display_Name__c != null ? record.Display_Name__c : '';
                    String newName = displayName + ' ' + branch.Name;
                    
                    if (record.Is_Active__c == false) {
                        newName += ' - Inactive';
                    }
                    
                    record.Name = newName.abbreviate(80);
                }
            }
        }
    }
}