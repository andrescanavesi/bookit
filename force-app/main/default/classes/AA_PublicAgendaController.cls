public without sharing class AA_PublicAgendaController {
    
    @AuraEnabled(cacheable=false)
    public static AA_Customer__c getOrCreateCustomer(String phoneNumber, Id businessId){
        AA_Logger logger = new AA_Logger(true);
        String cleanPhone = AA_CustomerTriggerHandler.normalizePhone(phoneNumber);
        logger.info('getOrCreateCustomer, phoneNumber '+phoneNumber+' cleanPhone '+cleanPhone+' businessId: '+businessId);
        List<AA_Customer__c> customers = [SELECT Id, Name, Email__c, First_Name__c, Last_Name__c, Phone_Number__c, Business__r.Business_Phone_Id__c
                                          FROM AA_Customer__c 
                                          WHERE Phone_Number__c = :cleanPhone 
                                          AND Business__c = :businessId
                                          LIMIT 1];
        if(!customers.isEmpty()){
            logger.info('getOrCreateCustomer, customer found by phone number '+cleanPhone+' businessId: '+businessId);
            return customers.get(0);
        }else{
            logger.info('getOrCreateCustomer, a new customer will be created with the phone number '+cleanPhone+' businessId: '+businessId);
            AA_Customer__c customer = new AA_Customer__c();
            customer.Name  = cleanPhone;
            customer.Phone_Number__c = cleanPhone;
            customer.Business__c = businessId;
            insert customer;
            logger.info('customer created, customerId '+customer.Id+ ' phoneNumber: '+cleanPhone+' businessId: '+businessId);
            return customer;
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static AA_Customer__c updateCustomer(Id customerId, String firstName, String lastName, String email, String comments, Boolean hasAllergies){
        AA_Logger logger = new AA_Logger(true);
        logger.info('updateCustomer, customerId '+customerId+ ' firstName: '+firstName+' lastName: '+lastName+' email: '+email+' comments: '+comments+' hasAllergies: '+hasAllergies);
        try{

            AA_Customer__c customer = new AA_Customer__c(
                Id = customerId,
                Name = firstName+' '+lastName ,
                First_Name__c = firstName,
                Last_Name__c = lastName,
                Email__c = email,
                Comments_From_Customer__c = comments,
                Has_Allergies__c = hasAllergies
            );

            update customer;
            logger.info('customer updated, customerId '+customerId+ ' firstName: '+firstName+' lastName: '+lastName+' email: '+email+' comments: '+comments+' hasAllergies: '+hasAllergies);
            return customer;
        }catch(Exception e){
            String message = 'error updating customer: '+e.getMessage()+' '+e.getStackTraceString();
            logger.error(message);
            throw new AuraHandledException(message);
        }
        
    }
    
    /*private static AA_Business__c getBusiness(Id businessId){        
        return [SELECT Id, Name FROM AA_Business__c  WHERE Id = :businessId LIMIT 1];
    }*/
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getBusinessInfo(Id businessId) {
        AA_Logger logger = new AA_Logger(true);
        //logger.info('getBusinessInfo called');
        List<AA_Business__c> businesses = [
            SELECT Id, Name, Address__c, Logo_URL__c, Phone_Number__c 
            FROM AA_Business__c 
            WHERE Id = :businessId
            LIMIT 1
        ];
        if(businesses.isEmpty()){
            return null;
        }
        
        AA_Business_Branch__c branch = getBusinessBranch(businessId);
        
        Map<String, String> result = new Map<String, String>();
        result.put('Logo_URL__c', businesses[0].Logo_URL__c);
        result.put('Phone_Number__c', businesses[0].Phone_Number__c);
        result.put('Address__c', businesses[0].Address__c);
        result.put('Branch_Name', branch.Display_Name__c != null ? branch.Display_Name__c : branch.Name);
        return result;
    }
    
    private static AA_Business_Branch__c getBusinessBranch(Id businessId){
        List<AA_Business_Branch__c> branches = [SELECT Id, Name, Address__c, Display_Name__c 
                                                FROM AA_Business_Branch__c 
                                                WHERE Business__c = :businessId
                                                ORDER BY CreatedDate DESC
                                                LIMIT 1];
        
        // TODO assuming for now that there is only one branch
        return branches.get(0);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<AA_Service_Category__c> getCategories(Id businessId) {
        AA_Logger logger = new AA_Logger(true);
        AA_Business_Branch__c branch = getBusinessBranch(businessId); 
        Id BRANCH_ID = branch.Id;
        //logger.info('getCategories, branch id '+branch.Id);
        List<AA_Service_Category__c> categories = [
            SELECT Id, Name, Display_Name__c, Description_Short__c 
            FROM AA_Service_Category__c 
            WHERE Business_Branch__c = :branch.Id
            AND Is_Active__c = true
            ORDER BY Name ASC 
            LIMIT 100
        ];
        //logger.info('categories: '+JSON.serializePretty(categories));
        
        return categories;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<AA_Service__c> getServices(Id businessId) {
        AA_Logger logger = new AA_Logger(true);
        AA_Business_Branch__c branch = getBusinessBranch(businessId); 
        //logger.info('getServices, branch id '+branch.Id);
        List<AA_Service__c>  services =  [SELECT Id, Name, Display_Name__c, Duration_Minutes__c, Price__c, AA_Service_Category__c, Requires_Manual_Coordination__c
                                          FROM AA_Service__c 
                                          WHERE Business_Branch__c = :branch.Id
                                          AND Is_Active__c = true
                                          LIMIT 100];
        
        //logger.info('services: '+JSON.serializePretty(services));
        
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
    public static List<AA_ComboSlot> getComboSlots(List<Id> serviceIds, String targetDateStr) {
        Date targetDate = Date.valueOf(targetDateStr);
        return AA_AppointmentService.getComboAvailableSlots(serviceIds, targetDate);
    }

    @AuraEnabled(cacheable=false)
    public static List<AA_Appointment__c> saveComboAppointments(Id customerId, String comboSlotJson, String formaPago) {
        AA_Logger logger = new AA_Logger(true);
        try {
            AA_ComboSlot combo = (AA_ComboSlot) JSON.deserialize(comboSlotJson, AA_ComboSlot.class);
            List<AA_Appointment__c> apps = new List<AA_Appointment__c>();
            
            for (AA_AvailableSlot slot : combo.slots) {
                AA_Appointment__c app = AA_AppointmentService.saveAppointment(customerId, slot.employeeId, slot.serviceId, slot.slotDayString, slot.slotTimeString, formaPago);
                apps.add(app);
            }
            
            // Update second app with comment linking to the first
            if (apps.size() == 2) {
                AA_Appointment__c app1 = [SELECT Id, Name FROM AA_Appointment__c WHERE Id = :apps[0].Id LIMIT 1];
                AA_Appointment__c app2 = [SELECT Id, Internal_Comments__c FROM AA_Appointment__c WHERE Id = :apps[1].Id LIMIT 1];
                
                String newComment = 'Agendado junto a la cita ' + app1.Name;
                app2.Internal_Comments__c = (app2.Internal_Comments__c != null ? app2.Internal_Comments__c + '\n' : '') + newComment;
                update app2;
                apps[1] = app2;
            }
            
            return apps;
        } catch (Exception e) {
            logger.error('error saving combo appointments: '+e.getMessage()+' '+e.getStackTraceString());
            throw new AuraHandledException('Error al confirmar la reserva: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<AA_Appointment__c> getMisTurnos(String celular, Id businessId) {
        String cleanPhone = AA_CustomerTriggerHandler.normalizePhone(celular);
        AA_Business_Branch__c branch = getBusinessBranch(businessId); 
        return [
           SELECT Id, Name, Employee__r.Name, Employee__r.First_Name__c, Employee__r.Last_Name__c, Start_Date_Time__c, End_Date_Time__c, Duration_Minutes__c, Service__r.Name, Service__r.Display_Name__c, 
           Status__c, Customer__r.Name, Amount__c, Customer_Confirmation_Date__c, Internal_Comments__c
           FROM AA_Appointment__c 
           WHERE Customer__r.Phone_Number__c = :cleanPhone 
           AND Start_Date_Time__c >= TODAY  
           AND Service__r.Business_Branch__c = :branch.Id
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
    
    @AuraEnabled(cacheable=false)
    public static void confirmarAsistencia(Id appointmentId) {
        AA_Logger logger = new AA_Logger(true);
        logger.info('confirmarAsistencia appointmentId: '+appointmentId);
        try {
            AA_Appointment__c appt = [SELECT Id, Internal_Comments__c FROM AA_Appointment__c WHERE Id = :appointmentId LIMIT 1];
            String comments = appt.Internal_Comments__c != null ? appt.Internal_Comments__c + '\nConfirmado por el cliente' : 'Confirmado por el cliente';
            
            appt.Customer_Confirmation_Date__c = System.now();
            appt.Internal_Comments__c = comments;
            
            update appt;
        } catch (Exception e) {
            logger.error('confirmarAsistencia error: '+e.getMessage()+' '+e.getStackTraceString());
            throw new AuraHandledException('Error al confirmar la asistencia: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static AA_Appointment__c recoordinarAppointment(Id oldAppointmentId, Id customerId, Id employeeId, Id serviceId, String dayString, String hourString) {
        AA_Logger logger = new AA_Logger(true);
        logger.info('recoordinarAppointment oldAppointmentId: '+oldAppointmentId);
        try {
            AA_Appointment__c oldAppt = [SELECT Id, Name, Internal_Comments__c FROM AA_Appointment__c WHERE Id = :oldAppointmentId LIMIT 1];
            
            // Crear la nueva cita
            AA_Appointment__c newApptObj = AA_AppointmentService.saveAppointment(customerId, employeeId, serviceId, dayString, hourString);
            
            // Consultar para tener el Name
            AA_Appointment__c newApptQuery = [SELECT Id, Name, Internal_Comments__c FROM AA_Appointment__c WHERE Id = :newApptObj.Id LIMIT 1];
            
            // Actualizar la vieja
            String oldComments = oldAppt.Internal_Comments__c != null ? oldAppt.Internal_Comments__c + '\nRecoordinado por el usuario a la cita ' + newApptQuery.Name : 'Recoordinado por el usuario a la cita ' + newApptQuery.Name;
            oldAppt.Status__c = 'Cancelled';
            oldAppt.Internal_Comments__c = oldComments;
            update oldAppt;
            
            // Actualizar la nueva
            String newComments = newApptQuery.Internal_Comments__c != null ? newApptQuery.Internal_Comments__c + '\nRecoordinado por el usuario desde la cita ' + oldAppt.Name : 'Recoordinado por el usuario desde la cita ' + oldAppt.Name;
            newApptQuery.Internal_Comments__c = newComments;
            update newApptQuery;
            
            return newApptQuery;
        } catch (Exception e) {
            logger.error('recoordinarAppointment error: '+e.getMessage()+' '+e.getStackTraceString());
            throw new AuraHandledException('Error al recoordinar la cita: ' + e.getMessage());
        }
    }
}