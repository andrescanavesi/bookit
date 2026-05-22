public with sharing class AA_SalonAppointmentsController {

    @AuraEnabled(cacheable=true)
    public static List<AA_Appointment__c> getSalonAppointments2() {
        return new List<AA_Appointment__c>();
    }

	@AuraEnabled(cacheable=true)
    public static List<AA_Appointment__c> getSalonAppointments() {
		 AA_Logger logger = new AA_Logger(true);
        
		String businessId = 'a02gL00000Ix6AH';
        try {
            // 1. Identificamos al usuario de la comunidad que está navegando el Back Office
            Id currentUserId = UserInfo.getUserId();
			logger.info('getSalonAppointments for user id '+currentUserId);
            
            // 2. Buscamos el registro de empleado vinculado a ese usuario para extraer su sucursal
            List<AA_Employee__c> employees = [
                SELECT Id, Business_Branch__c, Business_Id__c
                FROM AA_Employee__c 
                WHERE User__c = :currentUserId 
                LIMIT 1
            ];
            
            // Si el usuario no está configurado como empleado, retornamos una lista vacía de seguridad
            //if (employees.isEmpty()) {
             //   return new List<AA_Appointment__c>();
            //}
            
            //Id branchId = employees[0].Business_Branch__c;
			//Id businessId = employees[0].Business_Id__c;
			//businessId = 'a02gL00000Ix6AHQAZ'.left(15);

			
            
            // 3. Traemos las citas activas pertenecientes únicamente a este business (todos los branches)
            List<AA_Appointment__c> appointments =  [
                SELECT Id, Start_Date_Time__c, Status__c,
                       Customer__r.First_Name__c, Customer__r.Last_Name__c,
                       Service__r.Name, Employee__r.Name
                FROM AA_Appointment__c
                WHERE Business_Id__c = :businessId
                ORDER BY Start_Date_Time__c ASC
				LIMIT 1000
            ];
			logger.info('getSalonAppointments, size: '+appointments.size()+' business id: '+businessId);
			return appointments;
        } catch (Exception e) {
			 String message = 'error getting appointments for the business '+businessId+' '+e.getMessage()+' '+e.getStackTraceString();
            logger.error(message);
            throw new AuraHandledException(message);
        }
    }

}