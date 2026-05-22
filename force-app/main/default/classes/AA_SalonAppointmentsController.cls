public with sharing class AA_SalonAppointmentsController {

	@AuraEnabled(cacheable=true)
    public static List<AA_Appointment__c> getSalonAppointments() {
        try {
            // 1. Identificamos al usuario de la comunidad que está navegando el Back Office
            Id currentUserId = UserInfo.getUserId();
            
            // 2. Buscamos el registro de empleado vinculado a ese usuario para extraer su sucursal
            List<AA_Employee__c> employees = [
                SELECT Id, Business_Branch__c, Business_Id__c
                FROM AA_Employee__c 
                WHERE User__c = :currentUserId 
                LIMIT 1
            ];
            
            // Si el usuario no está configurado como empleado, retornamos una lista vacía de seguridad
            if (employees.isEmpty()) {
                return new List<AA_Appointment__c>();
            }
            
            Id branchId = employees[0].Business_Branch__c;
			//Id businessId = employees[0].Business_Id__c;
			Id businessId = 'a02gL00000Ix6AHQAZ';
			
            
            // 3. Traemos las citas activas pertenecientes únicamente a este business (todos los branches)
            return [
                SELECT Id, Start_Date_Time__c, Status__c,
                       Customer__r.First_Name__c, Customer__r.Last_Name__c,
                       Service__r.Name, Employee__r.Name
                FROM AA_Appointment__c
                WHERE Business_Id__c = :businessId
                ORDER BY Start_Date_Time__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener las citas del salón: ' + e.getMessage());
        }
    }

}