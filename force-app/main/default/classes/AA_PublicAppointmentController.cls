public without sharing class AA_PublicAppointmentController {

    public class SessionWrapper {
        @AuraEnabled public String customerName;
        @AuraEnabled public String serviceName;
        @AuraEnabled public Id serviceId;
    }

     // Wrapper para agrupar slots por día en la UI
    public class DayWrapper {
        @AuraEnabled public String dateLabel;
        @AuraEnabled public List<SlotWrapper> slots;
    }
    public class SlotWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String timeSlot;
    }
    
    @AuraEnabled(cacheable=true)
    public static SessionWrapper getCustomerNameFromSession(Id sessionId) {
        
            AA_WhatsApp_Session__c session = [
                SELECT Customer__r.Name, Selected_Service__c, Selected_Service__r.Name 
                FROM AA_WhatsApp_Session__c 
                WHERE Id = :sessionId 
                LIMIT 1
            ];
            SessionWrapper sw = new SessionWrapper();
            sw.customerName = session.Customer__r.Name;
            sw.serviceName = session.Selected_Service__r.Name;
            sw.serviceId = session.Selected_Service__c;
            return sw;
       
    }

    @AuraEnabled
    public static List<DayWrapper> getAvailableSlots(Id serviceId, Date startDate) {
        // Aquí llamas a tu lógica existente: AA_SlotService.getAvailableSlots(...)
        // Suponiendo que devuelve una lista de slots para los próximos 4 días.
        
        // Simulación de respuesta dinámica para que pruebes la lógica de "Sin Slots"
        List<DayWrapper> days = new List<DayWrapper>();
        List<AA_AvailableSlot> slots = AA_AppointmentService.getAvailableSlots(serviceId, startDate);
        return days; 
    }

    /**
     * Crea la cita y actualiza la sesión de WhatsApp.
     * @param sessionId El ID de la sesión actual (AA_WhatsApp_Session__c).
     * @param slotId El identificador del slot (ej: "EmployeeID|2026-04-20T10:00:00Z").
     */
    @AuraEnabled
    public static Boolean createAppointment(Id sessionId, String slotId) {
        try {
            // 1. Recuperamos los datos de la sesión para tener el contexto
            AA_WhatsApp_Session__c session = [
                SELECT Customer__c, Selected_Service__c 
                FROM AA_WhatsApp_Session__c 
                WHERE Id = :sessionId 
                LIMIT 1
            ];

            // 2. Parseamos el slotId 
            // Tip: Yo suelo mandarlo como "EmployeeId|DateTimeISO" para no hacer re-query de slots
            List<String> parts = slotId.split('\\|');
            Id employeeId = (Id)parts[0];
            String dateTimeStr = parts[1];
            Datetime startDateTime = (Datetime)JSON.deserialize('"' + dateTimeStr + '"', Datetime.class);

            

            // 3. Insertamos la Cita
            //AA_AppointmentService.saveAppointment(session.Customer__c, employeeId, session.Selected_Service__c, String dayString, String hourString){

            return true;
        } catch (Exception e) {
            // Logueamos el error y lanzamos una excepción que el LWC pueda capturar
            System.debug('Error en createAppointment: ' + e.getMessage());
            throw new AuraHandledException('Error al procesar la reserva: ' + e.getMessage());
        }
    }
}