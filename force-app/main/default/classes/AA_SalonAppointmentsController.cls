public with sharing class AA_SalonAppointmentsController {

    public class AgendaContext {
        @AuraEnabled public Boolean isAdmin { get; set; }
        @AuraEnabled public List<AA_Appointment__c> appointments { get; set; }
    }

    public class MatrixDataWrapper {
        @AuraEnabled public List<AA_Employee__c> employees {get;set;}
        @AuraEnabled public List<AA_Appointment__c> appointments {get;set;}
    }

    private static Id getBusinessId(){
        List<AA_Employee__c> employees = [SELECT Id, Name, Business_Id__c FROM AA_Employee__c 
        WHERE User__c = :UserInfo.getUserId() ORDER BY Name ASC];

        if (employees.isEmpty()) {
            throw new AuraHandledException('El empleado no está configurado como usuario');
        }
        
        AA_Employee__c currentEmployee = employees[0];
        return currentEmployee.Business_Id__c;
    }

    @AuraEnabled(cacheable=true)
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
                query += ' FROM AA_Appointment__c WHERE Business_Id__c = \'' + businessId + '\'';
                query += ' AND Status__c != \'Done\' ';
            
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

    @AuraEnabled
    public static void cancelAppointment(Id appointmentId) {
        try {
            AA_Appointment__c appt = new AA_Appointment__c(
                Id = appointmentId,
                Status__c = 'Cancelled',
                Cancelled_Date__c = System.now() // Sellamos la fecha para las métricas del salón
            );
            update appt;
        } catch (Exception e) {
            throw new AuraHandledException('Error al cancelar la cita: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void completeAppointment(Id appointmentId) {
        try {
            AA_Appointment__c appt = new AA_Appointment__c(
                Id = appointmentId,
                Status__c = 'Done',
                Done_Date__c = System.now() // Estampamos el momento exacto del cierre de caja
            );
            update appt;
        } catch (Exception e) {
            throw new AuraHandledException('Error al finalizar la cita: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static MatrixDataWrapper getMatrixData(Date selectedDate) {
        try {
            MatrixDataWrapper wrapper = new MatrixDataWrapper();

            Id businessId = getBusinessId();
            
            // 1. Recuperamos todos los profesionales del salón
            // WHERE User_Id__c = :UserInfo.getUserId()
            wrapper.employees = [
                SELECT Id, Name 
                FROM AA_Employee__c 
                WHERE Business_Branch__r.Business__c = :businessId
                AND Is_Admin__c = false
                ORDER BY Name ASC
            ];
            
             AA_Logger logger = new AA_Logger(true);
            

            // 2. Recuperamos las citas exclusivas de la fecha seleccionada (excluyendo canceladas)
            wrapper.appointments = [
                SELECT Id, Start_Date_Time__c, Status__c, Employee__c,
                       Customer__r.First_Name__c, Customer__r.Last_Name__c, 
                       Service__r.Name, Service__r.Duration_Minutes__c
                FROM AA_Appointment__c 
                WHERE DAY_ONLY(Start_Date_Time__c) = :selectedDate 
                AND Status__c != 'Cancelled'
            ];
            logger.info('getMatrixData, selectedDate '+selectedDate+' employees: '+wrapper.employees.size()+' appointments: '+wrapper.appointments.size());

            return wrapper;
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener datos de la matriz: ' + e.getMessage());
        }
    }

}