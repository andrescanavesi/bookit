public without sharing class Logger {

    private List<Log__c> logs;
    
    public Logger(){
        this.logs = new List<log__c>();
    }

    public void info(String message){
        log('INFO', message);
    }
    
    public void error(String message){
        log('ERROR', message);
    }
    
    private void log(String level, String message){
        Log__c log = new Log__c();
        log.Level__c = level;
        log.Log__c = message;
        logs.add(log);
        System.debug(level + ' '+ message);
        this.publish(); // TODO remove this
    }
    
    public void publish(){
        if(this.logs != null && !this.logs.isEmpty()){
            insert logs;
            this.logs.clear();
        }
        
    }
}