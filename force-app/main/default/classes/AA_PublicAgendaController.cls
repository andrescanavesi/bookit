public without sharing class AA_PublicAgendaController {
    
    private static Id BRANCH_ID = 'a03gL00000YGsWJQA1'; 
    private static String BUSSINESS_PHONE_ID = '1036897699507386';
    
    @AuraEnabled(cacheable=false)
    public static AA_Customer__c getOrCreateCustomer(String phoneNumber){
        AA_Logger logger = new AA_Logger(true);
        logger.info('getOrCreateCustomer, phoneNumber '+phoneNumber);
        // TODO for now we assume we have only one business
        AA_Business__c  business = getBusiness();
        //String fullName = 'guest'; 
        
        List<AA_Customer__c> customers = [SELECT Id, Name, Email__c, Phone_Number__c, Business__r.Business_Phone_Id__c  
                                          FROM AA_Customer__c 
                                          WHERE Phone_Number__c = :phoneNumber LIMIT 1];
        if(!customers.isEmpty()){
            logger.info('getOrCreateCustomer, customer found by found number '+phoneNumber);
            return customers.get(0);
        }else{
            logger.info('getOrCreateCustomer, a new customer will be created with the phone '+phoneNumber);
            AA_Customer__c customer = new AA_Customer__c();
            customer.Name  = phoneNumber;
            customer.Phone_Number__c = phoneNumber;
            customer.Business__c = business.Id;
            insert customer;
            return customer;
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static AA_Customer__c updateCustomer(Id customerId, String firstName, String lastName, String email, String comments){
        AA_Logger logger = new AA_Logger(true);
        logger.info('updateCustomer, customerId '+customerId+ ' firstName: '+firstName+' lastName: '+lastName+' email: '+email+' comments: '+comments);
        try{

            AA_Customer__c customer = new AA_Customer__c(
                Id = customerId,
                Name = firstName+' '+lastName ,
                First_Name__c = firstName,
                Last_Name__c = lastName,
                Email__c = email,
                Comments_From_Customer__c = comments
            );

            update customer;
            logger.info('customer updated, customerId '+customerId+ ' firstName: '+firstName+' lastName: '+lastName+' email: '+email+' comments: '+comments);
            return customer;
        }catch(Exception e){
            String message = 'error updating customer: '+e.getMessage()+' '+e.getStackTraceString();
            logger.error(message);
            throw new AuraHandledException(message);
        }
        
    }
    
    private static AA_Business__c getBusiness(){
        
        List<AA_Business__c> businesses = [SELECT Id FROM AA_Business__c 
                                           WHERE Business_Phone_Id__c = :BUSSINESS_PHONE_ID
                                           LIMIT 1];
        if(businesses.isEmpty()){
            throw new HandledException('business not found by phone number id '+BUSSINESS_PHONE_ID);
        }
        return businesses.get(0);
    }
    
    private static AA_Business_Branch__c getBusinessBranch(Id businessId){
        List<AA_Business_Branch__c> branches = [SELECT Id FROM AA_Business_Branch__c 
                                                WHERE Business__c = :businessId
                                                ORDER BY CreatedDate DESC
                                                LIMIT 1];
        
        // TODO assuming for now that there is only one branch
        return branches.get(0);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<AA_Service_Category__c> getCategories() {
        AA_Logger logger = new AA_Logger(true);
        logger.info('getCategories, branch id '+BRANCH_ID);
        List<AA_Service_Category__c> categories = [
            SELECT Id, Name, Description_Short__c 
            FROM AA_Service_Category__c 
            WHERE Business_Branch__c = :BRANCH_ID
            // Sugerencia: podrías agregar un campo 'Order__c' para controlar la posición
            ORDER BY Name ASC 
            LIMIT 100
        ];
        logger.info('categories: '+JSON.serializePretty(categories));
        
        return categories;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<AA_Service__c> getServices() {
        AA_Logger logger = new AA_Logger(true);
        logger.info('getServices, branch id '+BRANCH_ID);
        List<AA_Service__c>  services =  [SELECT Id, Name, Duration_Minutes__c, Price__c, AA_Service_Category__c
                                          FROM AA_Service__c 
                                          WHERE Business_Branch__c = :BRANCH_ID
                                          LIMIT 100];
        
        logger.info('services: '+JSON.serializePretty(services));
        
        return services;
    }

    @AuraEnabled(cacheable=false)
    public static List<AA_AvailableSlot> getAvailableSlots(Id serviceId, String targetDateStr) {
        // 1. Convertimos el string que llega de JS ('YYYY-MM-DD') al tipo Date de Apex
        AA_Logger logger = new AA_Logger(true);
        logger.info('getting available slots for service: '+serviceId+' targetDateStr: '+targetDateStr);
        Date targetDate = Date.valueOf(targetDateStr);
        
        
        logger.info('getting available slots for service: '+serviceId+' and date: '+targetDate);
        List<AA_AvailableSlot> slots =  AA_AppointmentService.getAvailableSlots(serviceId, targetDate);
        logger.info(JSON.serializePretty(slots));
        return slots;
        
    }

    @AuraEnabled(cacheable=false)
    public static AA_Appointment__c saveAppointment(Id customerId, Id employeeId, Id serviceId, String dayString, String hourString) {
        AA_Logger logger = new AA_Logger(true);
        logger.info('saveAppointment customerId: '+customerId+' employeeId: '+employeeId+' serviceId: '+serviceId+' dayString: '+dayString+' hourString: '+hourString);
        try {
            // Llamamos a tu clase de servicio para mantener la lógica separada
            AA_Appointment__c appointment = AA_AppointmentService.saveAppointment(customerId, employeeId, serviceId, dayString, hourString);
            logger.info('appointment created, id: '+appointment.Id);
            return appointment;
        } catch (Exception e) {
             logger.error('error updating customer: '+e.getMessage()+' '+e.getStackTraceString());
            // Empaquetamos el error para que el LWC lo entienda correctamente
            throw new AuraHandledException('Error al confirmar la reserva: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<AA_Appointment__c> getMisTurnos(String celular) {
        // Limpiamos el número por si el usuario ingresó espacios o guiones
        String cleanPhone = celular != null ? celular.replaceAll('[^0-9]', '') : '';
        
        return [
           SELECT Id, Name, Employee__r.Name, Start_Date_Time__c, End_Date_Time__c, Duration_Minutes__c, Service__r.Name, 
           Status__c, Customer__r.Name, Amount__c 
           FROM AA_Appointment__c 
           WHERE Customer__r.Phone_Number__c = :celular 
           AND Start_Date_Time__c >= TODAY  
           AND Service__r.Business_Branch__c = :BRANCH_ID
           AND Status__c = 'Pending'
           ORDER BY Start_Date_Time__c ASC
            LIMIT 10
        ];
    }

    @AuraEnabled(cacheable=false)
    public static void cancelarAppointment(Id appointmentId) {
         AA_Logger logger = new AA_Logger(true);
        logger.info('cancelarAppointment appointmentId: '+appointmentId);
        try {
            AA_Appointment__c app = new AA_Appointment__c(
                Id = appointmentId,
                Status__c = 'Cancelled'
            );
            update app;
        } catch (Exception e) {
             logger.error('cancelarAppointment error: '+e.getMessage()+' '+e.getStackTraceString());
            throw new AuraHandledException('Error al cancelar el turno: ' + e.getMessage());
        }
    }
    
}