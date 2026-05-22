public class AA_Scripts {

	
	/**
     * Elimina todos los registros de Log__c creados antes del día de hoy.
     * Utiliza un LIMIT para evitar exceder los límites de gobierno si el volumen es extremadamente alto.
	 * AA_Scripts.deleteOldLogs()
     */
    public static void deleteOldLogs() {
        System.debug('Iniciando borrado de logs viejos...');
        
        // Buscamos logs creados ayer o antes
        List<Log__c> logsToDelete = [
            SELECT Id FROM Log__c 
            WHERE CreatedDate < TODAY 
            LIMIT 10000
        ];
        
        if (!logsToDelete.isEmpty()) {
            Integer totalBorrados = logsToDelete.size();
            delete logsToDelete;
            System.debug('Se eliminaron con éxito ' + totalBorrados + ' logs viejos.');
        } else {
            System.debug('No se encontraron logs viejos para eliminar.');
        }
    }

	/**
     * Genera un volumen masivo de citas de prueba para las próximas 2 semanas.
     * @param slotsPorDia Cantidad de citas consecutivas a generar por cada día (ej: 15)
	 * AA_Scripts.generateBulkAppointments(2);
     */
    public static void generateBulkAppointments(Integer slotsPorDia) {
        System.debug('Iniciando generación masiva de citas...');

        // 1. Obtenemos registros base para asociar las citas (ajusta los filtros si necesitas un salón específico)
        List<AA_Customer__c> customers = [SELECT Id FROM AA_Customer__c WHERE Id = 'a08gL00000aNLQPQA4' LIMIT 1];
        List<AA_Employee__c> employees = [SELECT Id, Business_Branch__c FROM AA_Employee__c WHERE Id = 'a05gL00000GblwPQAR' LIMIT 1];
        List<AA_Service__c> services = [SELECT Id FROM AA_Service__c WHERE Id = 'a04gL00000BpRHZQA3' LIMIT 1];

        if (customers.isEmpty() || employees.isEmpty() || services.isEmpty()) {
            System.debug('Error: Debes tener al menos 1 cliente, 1 empleado y 1 servicio creados en la base de datos.');
            return;
        }

        Id defaultCustomerId = customers[0].Id;
        Id defaultEmployeeId = employees[0].Id;
        Id defaultBranchId = employees[0].Business_Branch__c;
        Id defaultServiceId = services[0].Id;

        List<AA_Appointment__c> appointmentsToInsert = new List<AA_Appointment__c>();
        Date todayDate = Date.today();

        // 2. Iteramos por los próximos 14 días (2 semanas)
        for (Integer dayOffset = 0; dayOffset < 14; dayOffset++) {
            Date targetDate = todayDate.addDays(dayOffset);
            
            // Opcional: Si quieres saltearte los domingos para simular un ambiente real
            Datetime dtCheck = Datetime.newInstance(targetDate, Time.newInstance(0,0,0,0));
            if (dtCheck.format('EEEE') == 'Sunday') {
                continue; 
            }

            // 3. Generamos las citas consecutivas para el día actual
            // Comenzamos a las 09:00 AM e incrementamos de a 30 minutos por cita
            Time startTime = Time.newInstance(9, 0, 0, 0);

            for (Integer slotIndex = 0; slotIndex < slotsPorDia; slotIndex++) {
                Time appointmentTime = startTime.addMinutes(slotIndex * 30);
                
                AA_Appointment__c app = new AA_Appointment__c();
                app.Customer__c = defaultCustomerId;
                app.Employee__c = defaultEmployeeId;
                app.Service__c = defaultServiceId;
                //app.Business_Branch__c = defaultBranchId;
                app.Start_Date_Time__c = Datetime.newInstance(targetDate, appointmentTime);
                app.Status__c = 'Pending';
                
                appointmentsToInsert.add(app);
            }
        }

        // 4. Inserción masiva de registros
        if (!appointmentsToInsert.isEmpty()) {
            insert appointmentsToInsert;
            System.debug('Se crearon exitosamente ' + appointmentsToInsert.size() + ' citas de prueba.');
        }
    }
}