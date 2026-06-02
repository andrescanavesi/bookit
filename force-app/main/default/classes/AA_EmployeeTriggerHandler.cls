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
    
    public static void handleAfterInsert(List<AA_Employee__c> newRecords) {
        List<AA_Employee_Working_Hour__c> workingHoursToInsert = new List<AA_Employee_Working_Hour__c>();
        List<String> daysOfWeek = new List<String>{'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'};
        
        Time startHour = Time.newInstance(9, 0, 0, 0);
        Time endHour = Time.newInstance(18, 0, 0, 0);
        Time breakStart = Time.newInstance(12, 0, 0, 0);
        Time breakEnd = Time.newInstance(13, 0, 0, 0);
        
        for (AA_Employee__c employee : newRecords) {
            for (String day : daysOfWeek) {
                // Generate a random 8 length string for Name
                String randomName = generateRandomString(8);
                
                AA_Employee_Working_Hour__c workingHour = new AA_Employee_Working_Hour__c(
                    Name = randomName,
                    Employee__c = employee.Id,
                    Day_Of_Week__c = day,
                    Start_Hour__c = startHour,
                    End_Hour__c = endHour,
                    Start_Default_Break_Hour__c = breakStart,
                    End_Default_Break_Hour__c = breakEnd
                );
                workingHoursToInsert.add(workingHour);
            }
        }
        
        if (!workingHoursToInsert.isEmpty()) {
            insert workingHoursToInsert;
        }
    }
    
    private static String generateRandomString(Integer len) {
        final String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
        String randStr = '';
        while (randStr.length() < len) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            randStr += chars.substring(idx, idx+1);
        }
        return randStr; 
    }
}