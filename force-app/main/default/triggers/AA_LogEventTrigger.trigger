trigger AA_LogEventTrigger on AA_Log_Event__e (after insert) {
    List<Log__c> logsToInsert = new List<Log__c>();
    
    for(AA_Log_Event__e event : Trigger.new) {
        logsToInsert.add(new Log__c(
            Level__c = event.Level__c,
            Log__c = event.Message__c,
            OwnerId = event.User_Id__c
        ));
    }
    
    if(!logsToInsert.isEmpty()) {
        insert logsToInsert;
    }
}