public without sharing class AA_Logger {
    
    private List<AA_Log_Event__e> logEvents;
    private Boolean publishImmediately = false;
    
    public AA_Logger(Boolean publishImmediately){
        this.logEvents = new List<AA_Log_Event__e>();
        this.publishImmediately = publishImmediately;
    }
    
    public AA_Logger(){
        this.logEvents = new List<AA_Log_Event__e>();
        this.publishImmediately = false;
    }
    
    
    public void info(String message){
        log('INFO', message);
    }
    
    public void error(String message){
        log('ERROR', message);
    }
    
    private void log(String level, String message){
        // Instanciamos el evento
        AA_Log_Event__e evt = new AA_Log_Event__e(
            Level__c = level,
            Message__c = message,
            User_Id__c =  UserInfo.getUserId()
        );
        
        logEvents.add(evt);
        System.debug(level + ' ' + message);
        
        if(publishImmediately){
            this.publish();
        }   
    }
    
    public void publish(){
        if(this.logEvents != null && !this.logEvents.isEmpty()){
            try {
                // Publicamos los eventos a través del EventBus
                List<Database.SaveResult> results = EventBus.publish(this.logEvents);
                
                // Opcional: Manejo de errores de publicación
                for (Database.SaveResult sr : results) {
                    if (!sr.isSuccess()) {
                        for(Database.Error err : sr.getErrors()) {
                            System.debug('Error publishing log event: ' + err.getStatusCode() + ' - ' + err.getMessage());
                        }
                    }
                }
            } catch(Exception e){
                System.debug('Exception publishing log events: ' + e.getMessage() + ' ' + e.getStackTraceString());
            }
            
            this.logEvents.clear();
        }
    }
}