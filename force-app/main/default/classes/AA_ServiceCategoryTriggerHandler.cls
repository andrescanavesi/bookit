public with sharing class AA_ServiceCategoryTriggerHandler {
    
    public static void handleBeforeInsertUpdate(List<AA_Service_Category__c> newRecords, Map<Id, AA_Service_Category__c> oldMap, Boolean isInsert, Boolean isUpdate) {
        
        List<AA_Service_Category__c> recordsToProcess = new List<AA_Service_Category__c>();
        Set<Id> branchIds = new Set<Id>();
        
        for (AA_Service_Category__c record : newRecords) {
            Boolean needsUpdate = false;
            
            if (isInsert) {
                needsUpdate = true;
            } else if (isUpdate) {
                AA_Service_Category__c oldRecord = oldMap.get(record.Id);
                if (record.Name != oldRecord.Name || 
                    record.Display_Name__c != oldRecord.Display_Name__c || 
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
            
            for (AA_Service_Category__c record : recordsToProcess) {
                AA_Business_Branch__c branch = branchMap.get(record.Business_Branch__c);
                if (branch != null) {
                    String displayName = record.Display_Name__c != null ? record.Display_Name__c : '';
                    String newName = displayName + ' ' + branch.Name;
                    record.Name = newName.abbreviate(75);
                }
            }
        }
    }
}