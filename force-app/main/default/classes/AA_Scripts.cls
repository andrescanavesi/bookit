public class AA_Scripts {

    private static Id BUSINESS_ID =  'a02gL00000Ix6AHQAZ'; // Zentidos

	
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
     * 
	 * AA_Scripts.deleteAllAppointments();
     */
    public static void deleteAllAppointments() {
        System.debug('Iniciando borrado  todos los appointments...');
        delete [SELECT Id FROM AA_Appointment__c];
    }

	

    /**
     * Genera un volumen masivo de citas de prueba dinámicas para las próximas 2 semanas.
     * @param slotsPorDia Cantidad de citas consecutivas a generar por cada día (ej: 6)
     * AA_Scripts.deleteAllAppointments();
     * AA_Scripts.generateBulkAppointments(6);
     */
    public static void generateBulkAppointments(Integer slotsPorDia) {
        System.debug('Iniciando generación masiva de citas...');

        Id businessId = BUSINESS_ID; 

        // 1. Obtenemos hasta 3 registros de forma dinámica, eliminando los IDs quemados
        List<AA_Customer__c> customers = [SELECT Id FROM AA_Customer__c 
            WHERE Business__c = :businessId ORDER BY CreatedDate DESC LIMIT 30];
        
        List<AA_Employee__c> employees = [SELECT Id, Business_Branch__c, Is_Admin__c 
            FROM AA_Employee__c  
            WHERE Business_Branch__r.Business__c = :businessId
            AND Is_Admin__c = false
            ORDER BY CreatedDate DESC
            LIMIT 5];
       
        List<AA_Service__c> services = [SELECT Id FROM AA_Service__c  WHERE Business_Branch__r.Business__c = :businessId 
            ORDER BY CreatedDate DESC LIMIT 5];

        if (customers.isEmpty() || employees.isEmpty() || services.isEmpty()) {
            System.debug('Error: Debes tener al menos 1 cliente, 1 empleado y 1 servicio creados en la base de datos. '+customers.isEmpty()+' '+employees.isEmpty()+' '+services.isEmpty());
            return;
        }

        List<AA_Appointment__c> appointmentsToInsert = new List<AA_Appointment__c>();
        Date todayDate = Date.today();

        // Almacenamos los tamaños reales de las listas para evitar índices fuera de rango (ListException)
        Integer cSize = customers.size();
        Integer eSize = employees.size();
        Integer sSize = services.size();

        System.debug('customers: '+cSize+' employees: '+eSize+' services: '+sSize);

        // 2. Iteramos por los próximos 7 días 
        for (Integer dayOffset = 0; dayOffset < 7; dayOffset++) {
            Date targetDate = todayDate.addDays(dayOffset);
            
            // Salteamos los domingos para simular un calendario real
            Datetime dtCheck = Datetime.newInstance(targetDate, Time.newInstance(0,0,0,0));
            if (dtCheck.format('EEEE') == 'Sunday') {
                continue; 
            }

            // 3. Comenzamos el día a las 09:00 AM
            Time startTime = Time.newInstance(9, 0, 0, 0);

            for (Integer slotIndex = 0; slotIndex < slotsPorDia; slotIndex++) {
                Time appointmentTime = startTime.addMinutes(slotIndex * 30);
                
                AA_Appointment__c app = new AA_Appointment__c();
                
                // Uso de Math.mod() para iterar de forma circular (Round-Robin) sobre los registros.
                // Esto garantiza variedad en la UI y evita solapamientos directos del mismo empleado.
                app.Customer__c = customers[Math.mod(slotIndex, cSize)].Id;
                app.Employee__c = employees[Math.mod(slotIndex, eSize)].Id;
                app.Service__c = services[Math.mod(slotIndex, sSize)].Id;
                
                app.Start_Date_Time__c = Datetime.newInstance(targetDate, appointmentTime);
                app.Status__c = 'Pending';
                
                appointmentsToInsert.add(app);
            }
        }

        // 4. Inserción masiva de registros
        if (!appointmentsToInsert.isEmpty()) {
            insert appointmentsToInsert;
            System.debug('Se crearon exitosamente ' + appointmentsToInsert.size() + ' citas de prueba distribuidas.');
        }
    }

    /**
     * Genera 50 clientes de prueba con nombres femeninos uruguayos, correos .invalid,
     * teléfonos locales y comentarios de salón de manicura.
     * * Para ejecutar:  AA_Scripts.generateCustomers();
     */
    public static void generateCustomers() {
        System.debug('Iniciando creación masiva de clientas...');

        // Listados de datos uruguayos
        List<String> firstNames = new List<String>{
            'Lucía', 'María', 'Camila', 'Sofía', 'Valentina', 'Martina', 'Romina', 
            'Florencia', 'Paula', 'Julieta', 'Micaela', 'Agustina', 'Valeria', 
            'Daniela', 'Mariana', 'Catalina', 'Emilia', 'Antonella', 'Carolina', 'Victoria'
        };

        List<String> lastNames = new List<String>{
            'Rodríguez', 'González', 'Pérez', 'Silva', 'García', 'Fernández', 
            'Martínez', 'Sosa', 'López', 'Gómez', 'Suárez', 'Díaz', 'Cabrera', 
            'Alonso', 'Gutiérrez'
        };

        List<String> phonePrefixes = new List<String>{'099', '095', '097'};

        // Comentarios típicos de manicura
        List<String> comments = new List<String>{
            'Prefiere siempre colores nude o vía láctea.',
            'Tiene cutículas muy sensibles, tratar con mucho cuidado.',
            'Alergia al acrílico, usar solo esmalte semipermanente o kapping de gel.',
            'Suele traer diseños de Pinterest (Nail Art minimalista).',
            'Se le suele quebrar la uña del índice derecho, reforzar.',
            'Viene cada 15 días religiosamente. Prefiere francesita.',
            'Le gusta charlar, prefiere café cortado durante la sesión.',
            'Uñas con tendencia a escamarse, aplicar base fortalecedora.',
            'Siempre pide tonos oscuros (bordeaux o negro) sin importar la estación.',
            'Prefiere uñas cortas y cuadradas para poder tipear cómoda.'
        };

        Id businessId = BUSINESS_ID;
        List<AA_Customer__c> customersToInsert = new List<AA_Customer__c>();

        for (Integer i = 0; i < 50; i++) {
            // Selecciones aleatorias
            String fName = firstNames[Math.mod(Math.abs(Crypto.getRandomInteger()), firstNames.size())];
            String lName = lastNames[Math.mod(Math.abs(Crypto.getRandomInteger()), lastNames.size())];
            String prefix = phonePrefixes[Math.mod(Math.abs(Crypto.getRandomInteger()), phonePrefixes.size())];
            String comment = comments[Math.mod(Math.abs(Crypto.getRandomInteger()), comments.size())];

            // Generación de teléfono: prefijo + 6 dígitos aleatorios
            String randomDigits = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);
            String phone = prefix + ' ' + randomDigits.substring(0, 3) + ' ' + randomDigits.substring(3, 6);

            // Generación de email: maria.gomez12@mail.invalid (limpiando tildes y espacios)
            String cleanFName = fName.toLowerCase().replaceAll('[áéíóú]', 'a').replaceAll('[^a-z]', '');
            String cleanLName = lName.toLowerCase().replaceAll('[áéíóú]', 'a').replaceAll('[^a-z]', '');
            String email = cleanFName + '.' + cleanLName + i + '@test.invalid';

            // Armado del registro
            AA_Customer__c customer = new AA_Customer__c();
            customer.Name = fName + ' ' + lName;
            customer.First_Name__c = fName;
            customer.Last_Name__c = lName;
            customer.Phone_Number__c = phone;
            customer.Email__c = email;
            customer.Business__c = businessId;
            customer.Comments_From_Customer__c = comment;

            customersToInsert.add(customer);
        }

        if (!customersToInsert.isEmpty()) {
            insert customersToInsert;
            System.debug('Se insertaron ' + customersToInsert.size() + ' clientas con éxito.');
        }
    }

}