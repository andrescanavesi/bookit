public with sharing class AA_SalonAppointmentsController {

    public class AgendaContext {
        @AuraEnabled public Boolean isAdmin { get; set; }
        @AuraEnabled public List<AA_Appointment__c> appointments { get; set; }
    }

    @AuraEnabled(cacheable=false)
    public static AgendaContext getSalonAppointments() {
        AA_Logger logger = new AA_Logger(true);
        String businessId = '';
        
        try {
            Id currentUserId = UserInfo.getUserId();
            logger.info('getSalonAppointments for user id ' + currentUserId);
            
            List<AA_Employee__c> employees = [
                SELECT Id, Business_Branch__c, Business_Id__c, Is_Admin__c
                FROM AA_Employee__c 
                WHERE User__c = :currentUserId 
                LIMIT 1
            ];

            if (employees.isEmpty()) {
                throw new AuraHandledException('El empleado no está configurado como usuario');
            }
            
            AA_Employee__c currentEmployee = employees[0];
            businessId = currentEmployee.Business_Id__c;
            
            // Inicializamos la consulta base
            String query = 'SELECT Id, Reminder_Sent_Date__c, Is_Reminder_Sent__c,  Customer_Confirmation_Date__c, Is_Customer_Confirmed__c, Start_Date_Time__c, Status__c, Customer__r.First_Name__c, Customer__r.Last_Name__c, Customer__r.Phone_Number__c, Service__r.Name, Service__r.Duration_Minutes__c, Employee__r.Name, Employee__c ';
                query += 'FROM AA_Appointment__c WHERE Business_Id__c = \'' + businessId + '\'';
            
            // Si NO es admin, agregamos un filtro estricto por su propio ID de empleado
            if (!currentEmployee.Is_Admin__c) {
                query += ' AND Employee__c = \'' + currentEmployee.Id + '\'';
            }
            
            query += ' ORDER BY Start_Date_Time__c ASC LIMIT 250';
            logger.info('getSalonAppointments query ' + query);
            
            List<AA_Appointment__c> appointments = Database.query(query);
            
            // Armamos la respuesta
            AgendaContext response = new AgendaContext();
            response.isAdmin = currentEmployee.Is_Admin__c;
            response.appointments = appointments;
            
            logger.info('getSalonAppointments success. Size: ' + appointments.size() + '. IsAdmin: ' + response.isAdmin);
            
            return response;
            
        } catch (Exception e) {
            String message = 'Error getting appointments for business ' + businessId + ': ' + e.getMessage();
            logger.error(message + ' ' + e.getStackTraceString());
            throw new AuraHandledException(message);
        }
    }

	@AuraEnabled
    public static void markReminderAsSent(Id appointmentId) {
        try {
            AA_Appointment__c appt = new AA_Appointment__c(
                Id = appointmentId,
                Reminder_Sent_Date__c = System.now()
            );
            update appt;
        } catch (Exception e) {
            throw new AuraHandledException('Error al registrar el envío del recordatorio: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void confirmAppointment(Id appointmentId) {
        try {
            AA_Appointment__c appt = new AA_Appointment__c(
                Id = appointmentId,
                Customer_Confirmation_Date__c = System.now(),
                Status__c = 'Confirmed' // Cambiamos el estado de la cita automáticamente
            );
            update appt;
        } catch (Exception e) {
            throw new AuraHandledException('Error al confirmar la cita: ' + e.getMessage());
        }
    }

}