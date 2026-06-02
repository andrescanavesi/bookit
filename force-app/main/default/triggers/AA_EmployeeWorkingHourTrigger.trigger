trigger AA_EmployeeWorkingHourTrigger on AA_Employee_Working_Hour__c (before insert, before update) {
    AA_EmployeeWorkingHourTriggerHandler.handleBeforeInsertUpdate(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate);
}