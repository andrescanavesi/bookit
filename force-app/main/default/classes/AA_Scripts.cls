public class AA_Scripts {

    private static Id BUSINESS_ID =  'a02gL00000Ix6AHQAZ'; // Zentidos

	
	/**
     * Elimina todos los registros de Log__c creados antes del día de hoy.
     * Utiliza un LIMIT para evitar exceder los límites de gobierno si el volumen es extremadamente alto.
	 * AA_Scripts.deleteOldLogs();
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
        System.debug('Iniciando generación masiva de citas aleatorias...');

        Id businessId = BUSINESS_ID; 

        // 1. Obtenemos registros dinámicos
        List<AA_Customer__c> customers = [SELECT Id FROM AA_Customer__c 
            WHERE Business__c = :businessId ORDER BY CreatedDate DESC LIMIT 30];
        
        List<AA_Employee__c> employees = [SELECT Id, Business_Branch__c, Is_Admin__c 
            FROM AA_Employee__c  
            WHERE Business_Branch__r.Business__c = :businessId
            AND Is_Admin__c = false
            ORDER BY CreatedDate DESC
            LIMIT 5];
       
        List<AA_Service__c> services = [SELECT Id FROM AA_Service__c  
            WHERE Business_Branch__r.Business__c = :businessId 
            ORDER BY CreatedDate DESC LIMIT 5];

        if (customers.isEmpty() || employees.isEmpty() || services.isEmpty()) {
            System.debug('Error: Debes tener al menos 1 cliente, 1 empleado y 1 servicio creados en la BD.');
            return;
        }

        List<AA_Appointment__c> appointmentsToInsert = new List<AA_Appointment__c>();
        Date todayDate = Date.today();

        Integer cSize = customers.size();
        Integer eSize = employees.size();
        Integer sSize = services.size();

        System.debug('customers: '+cSize+' employees: '+eSize+' services: '+sSize);

        // 2. Iteramos por los próximos 7 días 
        for (Integer dayOffset = 0; dayOffset < 21; dayOffset++) {
            Date targetDate = todayDate.addDays(dayOffset);
            
            // Salteamos los domingos para simular un calendario real
            Datetime dtCheck = Datetime.newInstance(targetDate, Time.newInstance(0,0,0,0));
            if (dtCheck.format('EEEE') == 'Sunday') {
                continue; 
            }

            // Memoria diaria para evitar que el mismo empleado tenga dos citas a la misma hora exacta
            Set<String> scheduledBlocks = new Set<String>();

            // 3. Generamos citas aleatorias para este día
            for (Integer slotIndex = 0; slotIndex < slotsPorDia; slotIndex++) {
                Boolean slotFound = false;
                Integer attempts = 0; // Salvaguarda para evitar loops infinitos

                while (!slotFound && attempts < 50) {
                    
                    // A. Seleccionamos un empleado al azar
                    Integer randomEmpIdx = Math.mod(Math.abs(Crypto.getRandomInteger()), eSize);
                    Id empId = employees[randomEmpIdx].Id;

                    // B. Generamos una hora aleatoria entre las 9:00 y las 17:00
                    Integer randomHour = 9 + Math.mod(Math.abs(Crypto.getRandomInteger()), 9); 
                    
                    // C. Generamos minutos aleatorios: o 0 o 30
                    Integer randomMin = Math.mod(Math.abs(Crypto.getRandomInteger()), 2) * 30;

                    // Clave de control: ej. "a05g...-14-30"
                    String blockKey = empId + '-' + randomHour + '-' + randomMin;

                    // D. Verificamos si este bloque ya fue ocupado hoy
                    if (!scheduledBlocks.contains(blockKey)) {
                        scheduledBlocks.add(blockKey);
                        slotFound = true; // Salimos del while

                        // Cliente y Servicio al azar
                        Integer randomCustIdx = Math.mod(Math.abs(Crypto.getRandomInteger()), cSize);
                        Integer randomServIdx = Math.mod(Math.abs(Crypto.getRandomInteger()), sSize);

                        Time appointmentTime = Time.newInstance(randomHour, randomMin, 0, 0);

                        AA_Appointment__c app = new AA_Appointment__c();
                        app.Customer__c = customers[randomCustIdx].Id;
                        app.Employee__c = empId;
                        app.Service__c = services[randomServIdx].Id;
                        app.Start_Date_Time__c = Datetime.newInstance(targetDate, appointmentTime);
                        app.Status__c = 'Pending';
                        
                        appointmentsToInsert.add(app);
                    }
                    attempts++;
                }
            }
        }

        // 4. Inserción masiva de registros
        if (!appointmentsToInsert.isEmpty()) {
            insert appointmentsToInsert;
            System.debug('Se crearon exitosamente ' + appointmentsToInsert.size() + ' citas de prueba aleatorias.');
        }
    }

    /**
     * Genera 50 clientes de prueba con nombres femeninos uruguayos, correos .invalid,
     * teléfonos locales y comentarios de salón de manicura.
     * * Para ejecutar:  AA_Scripts.generateCustomers('businessId');
     */
    public static void generateCustomers(Id businessId) {
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

        List<AA_Customer__c> customersToInsert = new List<AA_Customer__c>();

        for (Integer i = 0; i < 20; i++) {
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

    /**
     * Método 1: Genera la lista de horarios de trabajo para un empleado específico (Martes a Sábado).
     * @param empId El ID del empleado.
     * @return Lista de registros AA_Employee_Working_Hour__c listos para insertar.
     */
    public static List<AA_Employee_Working_Hour__c> createWorkingHoursForEmployee(Id empId) {
        List<AA_Employee_Working_Hour__c> whList = new List<AA_Employee_Working_Hour__c>();
        
        // Días laborables del salón
        List<String> workDays = new List<String>{'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'};
        
        // Definición de horarios (Usamos formato 24hs en Apex)
        Time startHour = Time.newInstance(9, 0, 0, 0);   // 09:00 AM
        Time endHour = Time.newInstance(18, 0, 0, 0);    // 06:00 PM
        Time breakStart = Time.newInstance(12, 0, 0, 0); // 12:00 PM (Mediodía)
        Time breakEnd = Time.newInstance(13, 0, 0, 0);   // 01:00 PM (13:00 hs)
        
        for (String day : workDays) {
            AA_Employee_Working_Hour__c wh = new AA_Employee_Working_Hour__c();
            wh.Employee__c = empId;
            wh.Day_Of_Week__c = day;
            
            // Asignación con los API Names confirmados en tu imagen
            wh.Start_Hour__c = startHour;
            wh.End_Hour__c = endHour;
            wh.Start_Default_Break_Hour__c = breakStart;
            wh.End_Default_Break_Hour__c = breakEnd;
            wh.Name = day;
            
            whList.add(wh);
        }
        
        return whList;
    }

    /**
     * Método 2: Obtiene todos los empleados, genera sus horarios usando el Método 1 
     * y realiza una inserción masiva (Bulk DML).
     * * Para ejecutar: AA_Scripts.generateWorkingHoursForAllEmployees();
     */
    public static void generateWorkingHoursForAllEmployees() {
        System.debug('Iniciando configuración masiva de horarios laborales...');
        
        // 1. Obtenemos todos los empleados que NO sean administradores
        List<AA_Employee__c> allEmployees = [SELECT Id, Name 
            FROM AA_Employee__c
            WHERE Business_Branch__r.Business__c = :BUSINESS_ID ];
        
        if (allEmployees.isEmpty()) {
            System.debug('No se encontraron empleados para configurar.');
            return;
        }

        // 2. Lista maestra para acumular todos los registros a insertar
        List<AA_Employee_Working_Hour__c> allWorkingHoursToInsert = new List<AA_Employee_Working_Hour__c>();
        
        // 3. Iteramos y acumulamos (sin hacer DML dentro del loop)
        for (AA_Employee__c emp : allEmployees) {
            List<AA_Employee_Working_Hour__c> empHours = createWorkingHoursForEmployee(emp.Id);
            allWorkingHoursToInsert.addAll(empHours);
        }
        
        // 4. Inserción masiva
        if (!allWorkingHoursToInsert.isEmpty()) {
            try {
                insert allWorkingHoursToInsert;
                System.debug('Éxito: Se crearon ' + allWorkingHoursToInsert.size() + ' registros de horarios para ' + allEmployees.size() + ' empleados.');
            } catch (Exception e) {
                System.debug('Error al insertar los horarios: ' + e.getMessage());
            }
        }
    }
    /**
     * Actualiza todos los registros existentes de horarios.
     * AA_Scripts.updateAllWorkingHours();
     */
    public static void updateAllWorkingHours() {
        System.debug('Actualizando todos los horarios (Sucursal y Empleados)...');

        // Horarios para Sucursal (8 AM a 8 PM)
        Time branchOpen = Time.newInstance(8, 0, 0, 0);
        Time branchClose = Time.newInstance(20, 0, 0, 0);
        
        List<AA_Branch_Working_Hour__c> branchHours = [SELECT Id FROM AA_Branch_Working_Hour__c];
        for (AA_Branch_Working_Hour__c bh : branchHours) {
            bh.Open_Time__c = branchOpen;
            bh.Close_Time__c = branchClose;
        }
        
        if (!branchHours.isEmpty()) {
            update branchHours;
            System.debug('Actualizados ' + branchHours.size() + ' horarios de sucursal.');
        }
        
        // Horarios para Empleados
        Time empStart = Time.newInstance(8, 0, 0, 0);
        Time empEnd = Time.newInstance(20, 0, 0, 0);
        Time breakStart = Time.newInstance(12, 0, 0, 0);
        Time breakEnd = Time.newInstance(13, 0, 0, 0);
        
        List<AA_Employee_Working_Hour__c> empHours = [SELECT Id FROM AA_Employee_Working_Hour__c];
        for (AA_Employee_Working_Hour__c eh : empHours) {
            eh.Start_Hour__c = empStart;
            eh.End_Hour__c = empEnd;
            eh.Start_Default_Break_Hour__c = breakStart;
            eh.End_Default_Break_Hour__c = breakEnd;
        }
        
        if (!empHours.isEmpty()) {
            update empHours;
            System.debug('Actualizados ' + empHours.size() + ' horarios de empleado.');
        }
    }
    /**
     * Genera 5 empleadas de prueba con nombres femeninos uruguayos para una sucursal.
     * * Para ejecutar: AA_Scripts.generateEmployees('Id_de_la_Sucursal');
     */
    public static void generateEmployees(Id branchId) {
        System.debug('Iniciando creación de 5 empleadas...');

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

        List<AA_Employee__c> employeesToInsert = new List<AA_Employee__c>();

        for (Integer i = 0; i < 5; i++) {
            String fName = firstNames[Math.mod(Math.abs(Crypto.getRandomInteger()), firstNames.size())];
            String lName = lastNames[Math.mod(Math.abs(Crypto.getRandomInteger()), lastNames.size())];

            AA_Employee__c emp = new AA_Employee__c();
            emp.First_Name__c = fName;
            emp.Last_Name__c = lName;
            emp.Business_Branch__c = branchId;

            employeesToInsert.add(emp);
        }

        if (!employeesToInsert.isEmpty()) {
            insert employeesToInsert;
            System.debug('Se insertaron ' + employeesToInsert.size() + ' empleadas con éxito.');
        }
    }

}