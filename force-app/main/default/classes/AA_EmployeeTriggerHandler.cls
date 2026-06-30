public with sharing class AA_EmployeeTriggerHandler {
    
    public static void handleBeforeInsertUpdate(List<AA_Employee__c> newRecords, Map<Id, AA_Employee__c> oldMap, Boolean isInsert, Boolean isUpdate) {
        
        List<AA_Employee__c> recordsToProcess = new List<AA_Employee__c>();
        Set<Id> branchIds = new Set<Id>();
        
        // Variables para validación de User__c único
        Set<Id> userIdsToCheck = new Set<Id>();
        
        // Variables para validación de desactivación
        Set<Id> deactivatedEmpIds = new Set<Id>();
        
        for (AA_Employee__c record : newRecords) {
            Boolean needsUpdate = false;
            
            if (isInsert) {
                needsUpdate = true;
            } else if (isUpdate) {
                AA_Employee__c oldRecord = oldMap.get(record.Id);
                if (record.Name != oldRecord.Name || 
                    record.First_Name__c != oldRecord.First_Name__c || 
                    record.Last_Name__c != oldRecord.Last_Name__c || 
                    record.Is_Active__c != oldRecord.Is_Active__c ||
                    record.Business_Branch__c != oldRecord.Business_Branch__c) {
                    needsUpdate = true;
                }
            }
            
            if (needsUpdate && record.Business_Branch__c != null) {
                recordsToProcess.add(record);
                branchIds.add(record.Business_Branch__c);
            }
            
            // Recolectar empleados que están siendo desactivados
            if (isUpdate) {
                AA_Employee__c oldRecord = oldMap.get(record.Id);
                if (record.Is_Active__c == false && oldRecord.Is_Active__c == true) {
                    deactivatedEmpIds.add(record.Id);
                }
            }
            
            // Recolectar User__c para validación de unicidad
            if (record.User__c != null) {
                if (isInsert) {
                    userIdsToCheck.add(record.User__c);
                } else if (isUpdate) {
                    AA_Employee__c oldRecord = oldMap.get(record.Id);
                    if (record.User__c != oldRecord.User__c) {
                        userIdsToCheck.add(record.User__c);
                    }
                }
            }
        }
        
        // ==========================================
        // Validación: User__c debe ser único
        // ==========================================
        if (!userIdsToCheck.isEmpty()) {
            // 1. Buscar en la base de datos si ya existen otros empleados usando esos Usuarios
            Set<Id> alreadyAssignedUsers = new Set<Id>();
            for (AA_Employee__c existingEmp : [SELECT Id, User__c FROM AA_Employee__c WHERE User__c IN :userIdsToCheck]) {
                // Si es un update, ignoramos el propio registro que estamos actualizando
                if (!isUpdate || !oldMap.containsKey(existingEmp.Id)) {
                    alreadyAssignedUsers.add(existingEmp.User__c);
                }
            }
            
            // 2. Controlar duplicados dentro del mismo lote (batch) que se está insertando/actualizando
            Set<Id> usersSeenInBatch = new Set<Id>();
            
            // 3. Aplicar el error a los registros inválidos
            for (AA_Employee__c record : newRecords) {
                if (record.User__c != null && userIdsToCheck.contains(record.User__c)) {
                    // Si ya está en BD o ya lo vimos en otro registro de este lote:
                    if (alreadyAssignedUsers.contains(record.User__c) || usersSeenInBatch.contains(record.User__c)) {
                        record.addError('Este Usuario de Salesforce ya está asignado a otro Empleado. No puede haber dos empleados vinculados al mismo Usuario.');
                    } else {
                        // Lo registramos como visto para las próximas iteraciones del lote
                        usersSeenInBatch.add(record.User__c);
                    }
                }
            }
        }
        // ==========================================
        
        // ==========================================
        // Validación: Desactivación de Empleado
        // ==========================================
        if (!deactivatedEmpIds.isEmpty()) {
            Set<Id> empsWithActiveAppts = new Set<Id>();
            // Buscamos si tienen citas activas (Pending, Confirmed, Rescheduled)
            for (AggregateResult ar : [
                SELECT Employee__c 
                FROM AA_Appointment__c 
                WHERE Employee__c IN :deactivatedEmpIds 
                AND Status__c IN ('Pending', 'Confirmed', 'Rescheduled')
                GROUP BY Employee__c
            ]) {
                empsWithActiveAppts.add((Id)ar.get('Employee__c'));
            }
            
            if (!empsWithActiveAppts.isEmpty()) {
                for (AA_Employee__c record : newRecords) {
                    if (empsWithActiveAppts.contains(record.Id)) {
                        record.addError('No se puede desactivar el empleado porque tiene turnos asociados con estado Pending, Confirmed o Rescheduled. Cancele o reasigne los turnos antes de desactivar.');
                    }
                }
            }
        }
        // ==========================================
        
        if (!recordsToProcess.isEmpty()) {
            Map<Id, AA_Business_Branch__c> branchMap = new Map<Id, AA_Business_Branch__c>([
                SELECT Id, Name FROM AA_Business_Branch__c WHERE Id IN :branchIds
            ]);
            
            for (AA_Employee__c record : recordsToProcess) {
                AA_Business_Branch__c branch = branchMap.get(record.Business_Branch__c);
                if (branch != null) {
                    String firstName = record.First_Name__c != null ? record.First_Name__c : '';
                    String lastName = record.Last_Name__c != null ? record.Last_Name__c : '';
                    
                    String newName = firstName;
                    if (String.isNotBlank(lastName)) {
                        newName += (String.isNotBlank(newName) ? ' ' : '') + lastName;
                    }
                    if (String.isNotBlank(branch.Name)) {
                        newName += (String.isNotBlank(newName) ? ' - ' : '') + branch.Name;
                    }
                    
                    if (record.Is_Active__c == false) {
                        newName += ' - Inactive';
                    }
                    
                    record.Name = newName.abbreviate(75);
                }
            }
        }
    }
    
    public static void handleAfterInsert(List<AA_Employee__c> newRecords) {
        List<AA_Employee_Working_Hour__c> workingHoursToInsert = new List<AA_Employee_Working_Hour__c>();
        List<String> daysOfWeek = new List<String>{'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'};
        
        Time startHour = Time.newInstance(9, 0, 0, 0);
        Time endHour = Time.newInstance(18, 0, 0, 0);
        Time breakStart = Time.newInstance(12, 0, 0, 0);
        Time breakEnd = Time.newInstance(13, 0, 0, 0);
        
        Set<Id> branchIds = new Set<Id>();
        
        for (AA_Employee__c employee : newRecords) {
            if (employee.Business_Branch__c != null) {
                branchIds.add(employee.Business_Branch__c);
            }
        }
        
        Map<String, AA_Branch_Working_Hour__c> branchHoursMap = new Map<String, AA_Branch_Working_Hour__c>();
        List<AA_Employee_Service__c> employeeServicesToInsert = new List<AA_Employee_Service__c>();
        
        if (!branchIds.isEmpty()) {
            List<AA_Branch_Working_Hour__c> bHours = [SELECT Id, Business_Branch__c, Day_Of_Week__c, Open_Time__c, Close_Time__c FROM AA_Branch_Working_Hour__c WHERE Business_Branch__c IN :branchIds];
            for (AA_Branch_Working_Hour__c bh : bHours) {
                branchHoursMap.put(bh.Business_Branch__c + '-' + bh.Day_Of_Week__c, bh);
            }
            
            List<AA_Service__c> branchServices = [SELECT Id, Business_Branch__c FROM AA_Service__c WHERE Business_Branch__c IN :branchIds];
            Map<Id, List<AA_Service__c>> servicesByBranch = new Map<Id, List<AA_Service__c>>();
            
            for (AA_Service__c service : branchServices) {
                if (!servicesByBranch.containsKey(service.Business_Branch__c)) {
                    servicesByBranch.put(service.Business_Branch__c, new List<AA_Service__c>());
                }
                servicesByBranch.get(service.Business_Branch__c).add(service);
            }
            
            for (AA_Employee__c employee : newRecords) {
                if (employee.Business_Branch__c != null && servicesByBranch.containsKey(employee.Business_Branch__c)) {
                    for (AA_Service__c service : servicesByBranch.get(employee.Business_Branch__c)) {
                        employeeServicesToInsert.add(new AA_Employee_Service__c(
                            Employee__c = employee.Id,
                            Service__c = service.Id
                        ));
                    }
                }
            }
        }
        
        for (AA_Employee__c employee : newRecords) {
            if (employee.Business_Branch__c != null) {
                for (String day : daysOfWeek) {
                    String key = employee.Business_Branch__c + '-' + day;
                    if (branchHoursMap.containsKey(key)) {
                        AA_Branch_Working_Hour__c bh = branchHoursMap.get(key);
                        workingHoursToInsert.add(new AA_Employee_Working_Hour__c(
                            Name = generateRandomString(8),
                            Employee__c = employee.Id,
                            Day_Of_Week__c = day,
                            Start_Hour__c = bh.Open_Time__c != null ? bh.Open_Time__c : Time.newInstance(9, 0, 0, 0),
                            End_Hour__c = bh.Close_Time__c != null ? bh.Close_Time__c : Time.newInstance(18, 0, 0, 0),
                            Start_Default_Break_Hour__c = breakStart,
                            End_Default_Break_Hour__c = breakEnd
                        ));
                    }
                }
            } else {
                for (String day : daysOfWeek) {
                    workingHoursToInsert.add(new AA_Employee_Working_Hour__c(
                        Name = generateRandomString(8),
                        Employee__c = employee.Id,
                        Day_Of_Week__c = day,
                        Start_Hour__c = Time.newInstance(9, 0, 0, 0),
                        End_Hour__c = Time.newInstance(18, 0, 0, 0),
                        Start_Default_Break_Hour__c = breakStart,
                        End_Default_Break_Hour__c = breakEnd
                    ));
                }
            }
        }
        
        if (!workingHoursToInsert.isEmpty()) {
            insert workingHoursToInsert;
        }
        if (!employeeServicesToInsert.isEmpty()) {
            insert employeeServicesToInsert;
        }
    }
    
    private static String generateRandomString(Integer len) {
        final String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
        String randStr = '';
        while (randStr.length() < len) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            randStr += chars.substring(idx, idx+1);
        }
        return randStr; 
    }
}