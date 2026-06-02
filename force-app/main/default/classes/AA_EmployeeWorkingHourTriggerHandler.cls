public with sharing class AA_EmployeeWorkingHourTriggerHandler {
    
    public static void handleBeforeInsertUpdate(List<AA_Employee_Working_Hour__c> newRecords, Map<Id, AA_Employee_Working_Hour__c> oldMap, Boolean isInsert, Boolean isUpdate) {
        
        List<AA_Employee_Working_Hour__c> recordsToProcess = new List<AA_Employee_Working_Hour__c>();
        Set<Id> employeeIds = new Set<Id>();
        
        for (AA_Employee_Working_Hour__c record : newRecords) {
            Boolean needsUpdate = false;
            
            if (isInsert) {
                needsUpdate = true;
            } else if (isUpdate) {
                AA_Employee_Working_Hour__c oldRecord = oldMap.get(record.Id);
                if (record.Name != oldRecord.Name || 
                    record.Employee__c != oldRecord.Employee__c || 
                    record.Day_Of_Week__c != oldRecord.Day_Of_Week__c) {
                    needsUpdate = true;
                }
            }
            
            if (needsUpdate && record.Employee__c != null) {
                recordsToProcess.add(record);
                employeeIds.add(record.Employee__c);
            }
        }
        
        if (!recordsToProcess.isEmpty()) {
            Map<Id, AA_Employee__c> employeeMap = new Map<Id, AA_Employee__c>([
                SELECT Id, Name FROM AA_Employee__c WHERE Id IN :employeeIds
            ]);
            
            for (AA_Employee_Working_Hour__c record : recordsToProcess) {
                AA_Employee__c employee = employeeMap.get(record.Employee__c);
                if (employee != null) {
                    String employeeName = employee.Name != null ? employee.Name : '';
                    String dayOfWeek = record.Day_Of_Week__c != null ? record.Day_Of_Week__c : '';
                    
                    String newName = employeeName;
                    if (String.isNotBlank(dayOfWeek)) {
                        newName += (String.isNotBlank(newName) ? ' - ' : '') + dayOfWeek;
                    }
                    
                    record.Name = newName.abbreviate(75);
                }
            }
        }
    }
}