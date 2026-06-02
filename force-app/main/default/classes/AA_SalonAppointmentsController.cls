public with sharing class AA_SalonAppointmentsController {

    public class AgendaContext {
        @AuraEnabled public Boolean isAdmin { get; set; }
        @AuraEnabled public List<AA_Appointment__c> appointments { get; set; }
    }

    public class MatrixDataWrapper {
        @AuraEnabled public List<AA_Employee__c> employees {get;set;}
        @AuraEnabled public List<AA_Appointment__c> appointments {get;set;}
        @AuraEnabled public List<AA_Employee_Absence__c> absences {get;set;}
        @AuraEnabled public List<AA_Employee_Working_Hour__c> workingHours {get;set;}
        @AuraEnabled public List<AA_Employee_Service__c> employeeServices {get;set;}
        @AuraEnabled public List<AA_Customer__c> allCustomers {get;set;}
        @AuraEnabled public List<AA_Service__c> allServices {get;set;}
        @AuraEnabled public AA_Branch_Working_Hour__c branchWorkingHour {get;set;}
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
    public static void confirmAppointment(Id appointmentId, String internalComments) {
        try {
            AA_Appointment__c appt = new AA_Appointment__c(
                Id = appointmentId,
                Customer_Confirmation_Date__c = System.now(),
                Status__c = 'Confirmed', // Cambiamos el estado de la cita automáticamente
                Internal_Comments__c = internalComments
            );
            update appt;
        } catch (Exception e) {
            throw new AuraHandledException('Error al confirmar la cita: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void cancelAppointment(Id appointmentId, String internalComments) {
        try {
            AA_Appointment__c appt = new AA_Appointment__c(
                Id = appointmentId,
                Status__c = 'Cancelled',
                Cancelled_Date__c = System.now(), 
                Internal_Comments__c = internalComments
            );
            update appt;
        } catch (Exception e) {
            throw new AuraHandledException('Error al cancelar la cita: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void setNoShowAppointment(Id appointmentId) {
        try {
            AA_Appointment__c appt = new AA_Appointment__c(
                Id = appointmentId,
                Status__c = 'No Show'
            );
            update appt;
        } catch (Exception e) {
            throw new AuraHandledException('Error al marcar la cita como No Show: ' + e.getMessage());
        }
    }

    // ACTUALIZADO: El método ahora procesa y guarda las observaciones internas del salón
    @AuraEnabled
    public static void completeAppointment(Id appointmentId, String internalComments) {
        try {
            AA_Appointment__c appt = new AA_Appointment__c(
                Id = appointmentId,
                Status__c = 'Done',
                Internal_Comments__c = internalComments,
                Done_Date__c = System.now() 
            );
            update appt;
        } catch (Exception e) {
            throw new AuraHandledException('Error al registrar la finalización: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static MatrixDataWrapper getMatrixData(Date selectedDate) {
         AA_Logger logger = new AA_Logger(true);
        try {
            MatrixDataWrapper wrapper = new MatrixDataWrapper();
            
             Id businessId = getBusinessId();
            
            // 1. Recuperamos todos los profesionales del salón
            wrapper.employees = [
                SELECT Id, Name 
                FROM AA_Employee__c 
                WHERE Business_Branch__r.Business__c = :businessId
                AND Is_Admin__c = false
                ORDER BY Name ASC
            ];
            
            wrapper.appointments = [
                SELECT Id, Name, Start_Date_Time__c, Status__c, Employee__c,
                       Customer__r.First_Name__c, Customer__r.Last_Name__c, Customer__r.Phone_Number__c,
                       Service__r.Name, Service__r.Duration_Minutes__c, Service__r.Price__c,
                       Internal_Comments__c, Is_Reminder_Sent__c, Is_Customer_Confirmed__c, Reminder_Sent_Date__c
                FROM AA_Appointment__c 
                WHERE DAY_ONLY(Start_Date_Time__c) = :selectedDate 
                AND Status__c != 'Cancelled'
                AND Service__r.Business_Branch__r.Business__c = :businessId
            ];

            // 3. Obtenemos las Ausencias (Licencias o Descansos ad-hoc) que toquen esta fecha
            wrapper.absences = [
                SELECT Id, Employee__c, Start_Date_Time__c, End_Date_Time__c, Category__c
                FROM AA_Employee_Absence__c
                WHERE DAY_ONLY(Start_Date_Time__c) <= :selectedDate 
                AND DAY_ONLY(End_Date_Time__c) >= :selectedDate
                AND Employee__r.Business_Branch__r.Business__c  = :businessId
            ];

            // 4. Obtenemos el Horario Laboral del día de la semana correspondiente
            Datetime dt = Datetime.newInstance(selectedDate, Time.newInstance(0,0,0,0));
            String dayOfWeek = dt.format('EEEE'); // Ej: 'Wednesday'
            
            wrapper.workingHours = [
                SELECT Employee__c, Start_Hour__c, End_Hour__c, Start_Default_Break_Hour__c, End_Default_Break_Hour__c, Day_Of_Week__c
                FROM AA_Employee_Working_Hour__c
                WHERE Day_Of_Week__c = :dayOfWeek
                AND Employee__r.Business_Branch__r.Business__c  = :businessId
            ];

            List<AA_Branch_Working_Hour__c> bwhList = [
                SELECT Open_Time__c, Close_Time__c
                FROM AA_Branch_Working_Hour__c
                WHERE Business_Branch__r.Business__c = :businessId
                AND Day_Of_Week__c = :dayOfWeek
                LIMIT 1
            ];
            if (!bwhList.isEmpty()) {
                wrapper.branchWorkingHour = bwhList[0];
            }

            wrapper.allServices = [SELECT Id, Name, Duration_Minutes__c, Price__c 
                FROM AA_Service__c 
                WHERE Business_Branch__r.Business__c  = :businessId
                ORDER BY Name ASC];
            
            wrapper.employeeServices = [SELECT Employee__c, Service__c 
                FROM AA_Employee_Service__c
                WHERE Employee__r.Business_Branch__r.Business__c  = :businessId];

            wrapper.allCustomers = [SELECT Id, Name FROM AA_Customer__c 
                WHERE Business__c = :businessId ORDER BY Name ASC];

            //logger.info('getMatrixData, selectedDate '+selectedDate+' employees: '+wrapper.employees.size()+' appointments: '+wrapper.appointments.size());
            return wrapper;
        } catch (Exception e) {
            String message = 'error getMatrixData: ' + e.getMessage();
            logger.error(message + ' ' + e.getStackTraceString());
            throw new AuraHandledException(message);
        }
    }

    // NUEVO: Método imperativo para guardar la cita desde el modal
    @AuraEnabled
    public static void createNewAppointment(Id customerId, Id employeeId, Id serviceId, Datetime startDateTime) {
        try {
            AA_Appointment__c appt = new AA_Appointment__c(
                Customer__c = customerId,
                Employee__c = employeeId,
                Service__c = serviceId,
                Start_Date_Time__c = startDateTime,
                Status__c = 'Pending'
            );
            insert appt;
        } catch (Exception e) {
            throw new AuraHandledException('Error al agendar la cita: ' + e.getMessage());
        }
    }

    // NUEVO: Método para crear bloqueos de horario (Ausencias/Descansos)
    @AuraEnabled
    public static void createAbsence(Id employeeId, Datetime startDateTime, Integer durationMinutes, String category) {
        AA_Logger logger = new AA_Logger(true);
        try {
            Datetime endDateTime = startDateTime.addMinutes(durationMinutes);
            String categoryDb = 'Break';
            logger.info('createAbsence, employee: '+employeeId+' startDateTime: '+startDateTime+' durationMinutes: '+durationMinutes+' categoryDb: '+categoryDb);
            AA_Employee_Absence__c abs = new AA_Employee_Absence__c(
                Employee__c = employeeId,
                Start_Date_Time__c = startDateTime,
                End_Date_Time__c = endDateTime,
                Category__c = categoryDb
            );
            insert abs;
        } catch (Exception e) {
            String message = 'Error on createAbsence: ' + e.getMessage();
            logger.error(message + ' ' + e.getStackTraceString());
            throw new AuraHandledException(message);
        }
    }

    // NUEVO: Método para eliminar un bloqueo manual
    @AuraEnabled
    public static void deleteAbsence(Id absenceId) {
        AA_Logger logger = new AA_Logger(true);
        
        try {
            logger.info('deleteAbsence, id: '+absenceId);
            delete new AA_Employee_Absence__c(Id = absenceId);
        } catch (Exception e) {
            String message = 'Error on deleteAbsence: ' + e.getMessage();
            logger.error(message + ' ' + e.getStackTraceString());
            throw new AuraHandledException(message);
        }
    }

    // NUEVO: Método para obtener los feriados de la semana visible
    @AuraEnabled(cacheable=true)
    public static List<AA_Branch_Holiday__c> getWeekHolidays(Date baseDate) {
        AA_Logger logger = new AA_Logger(true);
        try {
             logger.info('getWeekHolidays, date: '  + baseDate);
            Id businessId = getBusinessId();
            Date endDate = baseDate.addDays(6);
            return [
                SELECT Id, Name, Date__c 
                FROM AA_Branch_Holiday__c 
                WHERE Business_Branch__r.Business__c = :businessId 
                AND Date__c >= :baseDate 
                AND Date__c <= :endDate
            ];
        } catch (Exception e) {
            String message = 'Error getting week holidays: ' + e.getMessage();
            logger.error(message + ' ' + e.getStackTraceString());
            throw new AuraHandledException(message);
        }
    }

    // NUEVO: Método para reasignar una cita
    @AuraEnabled
    public static void reassignAppointment(Id appointmentId, Id newEmployeeId) {
        AA_Logger logger = new AA_Logger(true);
        try {
            AA_Appointment__c appt = new AA_Appointment__c(
                Id = appointmentId,
                Employee__c = newEmployeeId
            );
            update appt;
        } catch (Exception e) {
            String message = 'Error al reasignar cita: ' + e.getMessage();
            logger.error(message + ' ' + e.getStackTraceString());
            throw new AuraHandledException(message);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<AA_Employee__c> getEmployees() {
        Id businessId = getBusinessId();
        return [SELECT Id, Name, First_Name__c, Last_Name__c, Is_Admin__c, Business_Branch__r.Name 
                FROM AA_Employee__c 
                WHERE Business_Id__c = :businessId 
                ORDER BY First_Name__c ASC];
    }

    @AuraEnabled(cacheable=true)
    public static List<AA_Customer__c> getCustomers() {
        Id businessId = getBusinessId();
        return [SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, Phone_Number__c, Internal_Comments__c 
                FROM AA_Customer__c 
                WHERE Business__c = :businessId 
                ORDER BY First_Name__c ASC];
    }
}