public without sharing class AA_AppointmentService {
    
    private AA_Logger logger;
    
    public AA_AppointmentService(){
        this.logger = new AA_Logger(true);
    }
    
    
    public static List<AA_AvailableSlot> getAvailableSlots(Id serviceId, Date targetDate) {
         AA_Logger logger = new AA_Logger(true);
        logger.info('getting available slots for service: '+serviceId+' and date: '+targetDate);
        List<AA_AvailableSlot> finalAvailableSlots = new List<AA_AvailableSlot>();
        
        // 1. Get Service Duration
        AA_Service__c service = [SELECT Id, Name, Display_Name__c, Duration_Minutes__c, Business_Branch__c, Business_Branch__r.Name
                                 FROM AA_Service__c WHERE Id = :serviceId LIMIT 1];
        Integer durationMinutes = (Integer)service.Duration_Minutes__c;
        logger.info('Service name: '+service.Name+'. Duration in minutes: '+durationMinutes);
        
        // 2. Find all Employees who provide this Service
        List<AA_Employee_Service__c> empServices = [
            SELECT Employee__c, Employee__r.Name, Employee__r.First_Name__c, Employee__r.Last_Name__c 
            FROM AA_Employee_Service__c 
            WHERE Service__c = :serviceId
        ];
        
        if (empServices.isEmpty()) {
            return finalAvailableSlots;
        }
        
        Set<Id> employeeIds = new Set<Id>();
        Map<Id, String> employeeNames = new Map<Id, String>();
        for (AA_Employee_Service__c es : empServices) {
            employeeIds.add(es.Employee__c);
            String fName = es.Employee__r.First_Name__c != null ? es.Employee__r.First_Name__c + ' ' : '';
            employeeNames.put(es.Employee__c, fName + es.Employee__r.Last_Name__c);
        }
        
        // 3. Setup Time Context
        Datetime dtContext = Datetime.newInstance(targetDate, Time.newInstance(0,0,0,0));
        String dayOfWeek = dtContext.format('EEEE', 'en_US'); 
        Datetime dayEnd = dtContext.addDays(1);
        
        // 4. BULK QUERY: Get Working Hours for ALL eligible employees
        Map<Id, AA_Employee_Working_Hour__c> workingHoursMap = new Map<Id, AA_Employee_Working_Hour__c>();
        for (AA_Employee_Working_Hour__c wh : [
            SELECT Employee__c, Start_Hour__c, End_Hour__c, Start_Default_Break_Hour__c, End_Default_Break_Hour__c
            FROM AA_Employee_Working_Hour__c
            WHERE Employee__c IN :employeeIds AND Day_Of_Week__c = :dayOfWeek
        ]) {
            workingHoursMap.put(wh.Employee__c, wh);
        }
        
        
        // 5. BULK QUERY: Get Appointments & Absences for ALL eligible employees
        List<AA_Appointment__c> allAppointments = [
            SELECT Employee__c, Start_Date_Time__c, End_Date_Time__c 
            FROM AA_Appointment__c 
            WHERE Employee__c IN :employeeIds 
            AND Status__c NOT IN ('Cancelled', 'No Show')
            AND Start_Date_Time__c >= :dtContext AND Start_Date_Time__c < :dayEnd
        ];
        
        List<AA_Employee_Absence__c> allAbsences = [
            SELECT Employee__c, Start_Date_Time__c, End_Date_Time__c, Category__c 
            FROM AA_Employee_Absence__c 
            WHERE Employee__c IN :employeeIds 
            AND Start_Date_Time__c >= :dtContext AND Start_Date_Time__c < :dayEnd
        ];
        
        // 6. Map Blockers to Specific Employees in Memory
        Map<Id, List<AA_TimeBlock>> employeeBlockers = new Map<Id, List<AA_TimeBlock>>();
        Map<Id, Boolean> employeeHasRescheduledBreak = new Map<Id, Boolean>();
        
        for (Id empId : employeeIds) {
            employeeBlockers.put(empId, new List<AA_TimeBlock>());
            employeeHasRescheduledBreak.put(empId, false);
        }
        
        for (AA_Employee_Absence__c abs : allAbsences) {
            employeeBlockers.get(abs.Employee__c).add(new AA_TimeBlock(abs.Start_Date_Time__c, abs.End_Date_Time__c));
            if (abs.Category__c == 'Rescheduled Break') {
                employeeHasRescheduledBreak.put(abs.Employee__c, true);
            }
        }
        
        for (AA_Appointment__c appt : allAppointments) {
            employeeBlockers.get(appt.Employee__c).add(new AA_TimeBlock(appt.Start_Date_Time__c, appt.End_Date_Time__c));
        }
        
        // 7. Calculate Slots per Employee
        for (Id empId : workingHoursMap.keySet()) {
            AA_Employee_Working_Hour__c wh = workingHoursMap.get(empId);
            List<AA_TimeBlock> blockers = employeeBlockers.get(empId);
            
            // Add Default Break if not overwritten
            if (!employeeHasRescheduledBreak.get(empId) && wh.Start_Default_Break_Hour__c != null && wh.End_Default_Break_Hour__c != null) {
                blockers.add(new AA_TimeBlock(
                    Datetime.newInstance(targetDate, wh.Start_Default_Break_Hour__c),
                    Datetime.newInstance(targetDate, wh.End_Default_Break_Hour__c)
                ));
            }
            
            Datetime shiftStart = Datetime.newInstance(targetDate, wh.Start_Hour__c);
            Datetime shiftEnd = Datetime.newInstance(targetDate, wh.End_Hour__c);
            Datetime currentPointer = shiftStart;
            
            // The Jump Algorithm applied to the specific employee
            while (currentPointer.addMinutes(durationMinutes) <= shiftEnd) {
                Datetime potentialSlotEnd = currentPointer.addMinutes(durationMinutes);
                Boolean isSlotFree = true;
                
                for (AA_TimeBlock block : blockers) {
                    if (currentPointer < block.endTime && potentialSlotEnd > block.startTime) {
                        isSlotFree = false;
                        currentPointer = block.endTime; 
                        break; 
                    }
                }
                
                if (isSlotFree) {
                    // Create the final payload option
                    finalAvailableSlots.add(new AA_AvailableSlot(
                        currentPointer, 
                        empId, 
                        employeeNames.get(empId),
                        service.Display_Name__c != null ? service.Display_Name__c : service.Name,
                        service.Id,
                        service.Business_Branch__r.Name,
                        service.Business_Branch__c,
                        durationMinutes
                    ));
                    currentPointer = potentialSlotEnd; 
                }
            }
        }
        logSchedulingSimulations(finalAvailableSlots, employeeBlockers, workingHoursMap, targetDate);
        logger.info('available slots: '+finalAvailableSlots.size());
        return finalAvailableSlots;
    }
    
    public static List<AA_AvailableSlot> getAvailableSlots(Id serviceId, Date startDate, Date endDate) {
         AA_Logger logger = new AA_Logger(true);
        logger.info('Getting available slots for service: ' + serviceId + ' from ' + startDate + ' to ' + endDate);
        List<AA_AvailableSlot> finalAvailableSlots = new List<AA_AvailableSlot>();
        
        // 1. Get Service & Duration
        AA_Service__c service = [SELECT Id, Name, Display_Name__c, Duration_Minutes__c, Business_Branch__c, Business_Branch__r.Name 
                                 FROM AA_Service__c WHERE Id = :serviceId LIMIT 1];
        Integer durationMinutes = (Integer)service.Duration_Minutes__c;
        
        // 2. Find Employees
        List<AA_Employee_Service__c> empServices = [SELECT Employee__c, Employee__r.Name, Employee__r.First_Name__c, Employee__r.Last_Name__c FROM AA_Employee_Service__c WHERE Service__c = :serviceId];
        if (empServices.isEmpty()) return finalAvailableSlots;
        
        Set<Id> employeeIds = new Set<Id>();
        Map<Id, String> employeeNames = new Map<Id, String>();
        for (AA_Employee_Service__c es : empServices) {
            employeeIds.add(es.Employee__c);
            String fName = es.Employee__r.First_Name__c != null ? es.Employee__r.First_Name__c + ' ' : '';
            employeeNames.put(es.Employee__c, fName + es.Employee__r.Last_Name__c);
        }
        
        // 3. Setup Range Context
        Datetime startRangeDt = Datetime.newInstance(startDate, Time.newInstance(0,0,0,0));
        Datetime endRangeDt = Datetime.newInstance(endDate.addDays(1), Time.newInstance(0,0,0,0));
        
        // 4. BULK QUERY: All Working Hours for these employees (Any Day of Week)
        // Key: EmployeeId + DayOfWeek (e.g. "003..._Monday")
        Map<String, AA_Employee_Working_Hour__c> workingHoursMap = new Map<String, AA_Employee_Working_Hour__c>();
        for (AA_Employee_Working_Hour__c wh : [
            SELECT Employee__c, Day_Of_Week__c, Start_Hour__c, End_Hour__c, Start_Default_Break_Hour__c, End_Default_Break_Hour__c
            FROM AA_Employee_Working_Hour__c
            WHERE Employee__c IN :employeeIds
        ]) {
            workingHoursMap.put(wh.Employee__c + '_' + wh.Day_Of_Week__c, wh);
        }
        
        // 5. BULK QUERY: Blockers for the ENTIRE range
        Map<Id, List<AA_TimeBlock>> employeeBlockers = new Map<Id, List<AA_TimeBlock>>();
        Map<String, Boolean> employeeDayHasRescheduledBreak = new Map<String, Boolean>(); // Key: EmpId + DateString
        
        for (Id empId : employeeIds) employeeBlockers.put(empId, new List<AA_TimeBlock>());
        
        for (AA_Employee_Absence__c abs : [SELECT Employee__c, Start_Date_Time__c, End_Date_Time__c, Category__c 
                                           FROM AA_Employee_Absence__c 
                                           WHERE Employee__c IN :employeeIds 
                                           AND Start_Date_Time__c >= :startRangeDt AND Start_Date_Time__c < :endRangeDt]) {
                                               employeeBlockers.get(abs.Employee__c).add(new AA_TimeBlock(abs.Start_Date_Time__c, abs.End_Date_Time__c));
                                               if (abs.Category__c == 'Rescheduled Break') {
                                                   employeeDayHasRescheduledBreak.put(abs.Employee__c + '_' + abs.Start_Date_Time__c.format('yyyy-MM-dd'), true);
                                               }
                                           }
        
        for (AA_Appointment__c appt : [SELECT Employee__c, Start_Date_Time__c, End_Date_Time__c 
                                       FROM AA_Appointment__c 
                                       WHERE Employee__c IN :employeeIds 
                                       AND Status__c NOT IN ('Cancelled', 'No Show')
                                       AND Start_Date_Time__c >= :startRangeDt AND Start_Date_Time__c < :endRangeDt]) {
                                           employeeBlockers.get(appt.Employee__c).add(new AA_TimeBlock(appt.Start_Date_Time__c, appt.End_Date_Time__c));
                                       }
        
        // 6. TRIPLE LOOP: Range -> Employees -> Jump Algorithm
        for (Date currentDate = startDate; currentDate <= endDate; currentDate = currentDate.addDays(1)) {
            
            Datetime contextDt = Datetime.newInstance(currentDate, Time.newInstance(0,0,0,0));
            String dayOfWeek = contextDt.format('EEEE', 'en_US');
            String dateKey = currentDate.year() + '-' + currentDate.month() + '-' + currentDate.day(); // Simple key for break check
            
            for (Id empId : employeeIds) {
                String whKey = empId + '_' + dayOfWeek;
                if (!workingHoursMap.containsKey(whKey)) continue; // Employee doesn't work this day
                
                AA_Employee_Working_Hour__c wh = workingHoursMap.get(whKey);
                List<AA_TimeBlock> dailyBlockers = employeeBlockers.get(empId);
                
                // Local copy of blockers for this specific calculation
                List<AA_TimeBlock> activeBlockers = new List<AA_TimeBlock>(dailyBlockers);
                
                // Handle Default Break for this specific day
                Boolean hasRescheduled = employeeDayHasRescheduledBreak.containsKey(empId + '_' + contextDt.format('yyyy-MM-dd'));
                if (!hasRescheduled && wh.Start_Default_Break_Hour__c != null) {
                    activeBlockers.add(new AA_TimeBlock(
                        Datetime.newInstance(currentDate, wh.Start_Default_Break_Hour__c),
                        Datetime.newInstance(currentDate, wh.End_Default_Break_Hour__c)
                    ));
                }
                
                // The Jump Algorithm
                Datetime shiftStart = Datetime.newInstance(currentDate, wh.Start_Hour__c);
                Datetime shiftEnd = Datetime.newInstance(currentDate, wh.End_Hour__c);
                Datetime currentPointer = shiftStart;
                
                while (currentPointer.addMinutes(durationMinutes) <= shiftEnd) {
                    Datetime potentialSlotEnd = currentPointer.addMinutes(durationMinutes);
                    Boolean isSlotFree = true;
                    
                    for (AA_TimeBlock block : activeBlockers) {
                        if (currentPointer < block.endTime && potentialSlotEnd > block.startTime) {
                            isSlotFree = false;
                            currentPointer = block.endTime; 
                            break; 
                        }
                    }
                    
                    if (isSlotFree) {
                        finalAvailableSlots.add(new AA_AvailableSlot(
                            currentPointer, empId, employeeNames.get(empId),
                            service.Display_Name__c != null ? service.Display_Name__c : service.Name, service.Id, service.Business_Branch__r.Name, service.Business_Branch__c, durationMinutes
                        ));
                        currentPointer = potentialSlotEnd; 
                    }
                }
            }
        }
        
        return finalAvailableSlots;
    }
    
    private static void logSchedulingSimulations(
        List<AA_AvailableSlot> generatedSlots, 
        Map<Id, List<AA_TimeBlock>> employeeBlockers,
        Map<Id, AA_Employee_Working_Hour__c> workingHoursMap,
        Date targetDate) 
    {
        AA_Logger logger = new AA_Logger(true);
        Integer minGapMinutes = 60;
        
        Map<Id, Set<Datetime>> clusterSetMap = new Map<Id, Set<Datetime>>();
        Map<Id, Set<Datetime>> gapSetMap = new Map<Id, Set<Datetime>>();
        Map<Id, List<AA_AvailableSlot>> empSlotsMap = new Map<Id, List<AA_AvailableSlot>>();
        
        for (AA_AvailableSlot slot : generatedSlots) {
            Id empId = slot.employeeId;
            AA_Employee_Working_Hour__c wh = workingHoursMap.get(empId);
            if (wh == null) continue;
            
            if(!empSlotsMap.containsKey(empId)) empSlotsMap.put(empId, new List<AA_AvailableSlot>());
            if(!clusterSetMap.containsKey(empId)) clusterSetMap.put(empId, new Set<Datetime>());
            if(!gapSetMap.containsKey(empId)) gapSetMap.put(empId, new Set<Datetime>());
            
            empSlotsMap.get(empId).add(slot);
            
            Datetime shiftStart = Datetime.newInstance(targetDate, wh.Start_Hour__c);
            Datetime shiftEnd = Datetime.newInstance(targetDate, wh.End_Hour__c);
            List<AA_TimeBlock> blockers = employeeBlockers.get(empId);
            
            Datetime slotStart = slot.slotTime;
            Datetime slotEnd = slot.endTime;
            
            // --- Strategy 1: Cluster Scheduling ---
            Boolean isAdjacent = false;
            if (slotStart == shiftStart || slotEnd == shiftEnd) {
                isAdjacent = true;
            } else {
                for (AA_TimeBlock block : blockers) {
                    if (slotStart == block.endTime || slotEnd == block.startTime) {
                        isAdjacent = true;
                        break;
                    }
                }
            }
            if (isAdjacent) {
                clusterSetMap.get(empId).add(slotStart);
            }
            
            // --- Strategy 2: Minimum Gap (60 mins) ---
            Datetime closestBefore = shiftStart;
            Datetime closestAfter = shiftEnd;
            
            for (AA_TimeBlock block : blockers) {
                if (block.endTime <= slotStart && block.endTime > closestBefore) {
                    closestBefore = block.endTime;
                }
                if (block.startTime >= slotEnd && block.startTime < closestAfter) {
                    closestAfter = block.startTime;
                }
            }
            
            Long gapBeforeMins = (slotStart.getTime() - closestBefore.getTime()) / 60000;
            Long gapAfterMins = (closestAfter.getTime() - slotEnd.getTime()) / 60000;
            
            Boolean isValidGapBefore = (gapBeforeMins == 0 || gapBeforeMins >= minGapMinutes);
            Boolean isValidGapAfter = (gapAfterMins == 0 || gapAfterMins >= minGapMinutes);
            
            if (isValidGapBefore && isValidGapAfter) {
                gapSetMap.get(empId).add(slotStart);
            }
        }
        
        // Print tables per employee
        for (Id empId : empSlotsMap.keySet()) {
            List<AA_AvailableSlot> empSlots = empSlotsMap.get(empId);
            String empName = empSlots[0].employeeName;
            
            List<String> logLines = new List<String>();
            logLines.add('\\n======================================================================');
            logLines.add(' SIMULATION: ' + empName + ' | Date: ' + targetDate);
            logLines.add('======================================================================');
            logLines.add(' HORA        | ACTUAL         | ESTRATEGIA 1 (Cluster) | ESTRATEGIA 2 (Gap 60m)');
            logLines.add('----------------------------------------------------------------------');
            
            for (AA_AvailableSlot slot : empSlots) {
                String tStr = slot.slotTimeString; // Using the GMT-3 formatted string
                String clusterCol = clusterSetMap.get(empId).contains(slot.slotTime) ? tStr.rightPad(22) : 'X'.rightPad(22);
                String gapCol = gapSetMap.get(empId).contains(slot.slotTime) ? tStr : 'X';
                
                logLines.add(' ' + tStr.rightPad(11) + ' | ' + tStr.rightPad(14) + ' | ' + clusterCol + ' | ' + gapCol);
            }
            logLines.add('======================================================================\\n');
            
            logger.info(String.join(logLines, '\\n'));
        }
    }
    
    public static AA_Appointment__c saveAppointment(Id customerId, Id employeeId, Id serviceId, String dayString, String hourString){
        return saveAppointment(customerId, employeeId, serviceId, dayString, hourString, null);
    }
    
    public static AA_Appointment__c saveAppointment(Id customerId, Id employeeId, Id serviceId, String dayString, String hourString, String formaPago){
        AA_Appointment__c  app = new AA_Appointment__c();
        app.Customer__c = customerId;
        app.Employee__c = employeeId;
        app.Service__c = serviceId;
        app.Start_Date_Time__c = convertToGmtMinus3(dayString, hourString);
        app.Status__c = 'Pending';
        if (String.isNotBlank(formaPago)) {
            app.Payment_Method__c = formaPago;
        }
        insert app;
        return app;
    }
    
    public static Datetime convertToGmtMinus3(String dateStr, String timeStr) {
        // 1. Parse the Date (YYYY-MM-DD)
        Date d = Date.valueOf(dateStr);
        
        // 2. Parse the Time (HH:mm)
        List<String> timeParts = timeStr.split(':');
        Integer hour = Integer.valueOf(timeParts[0]);
        Integer minute = Integer.valueOf(timeParts[1]);
        
        // 3. Create a Datetime instance
        // newInstance assumes the input is in the "Local" time of the running user
        Datetime localDt = Datetime.newInstance(d, Time.newInstance(hour, minute, 0, 0));
        
        // 4. Adjust for GMT-3
        // To store 14:30 (GMT-3) in Salesforce (UTC), we must ADD 3 hours.
        // 14:30 + 3 = 17:30 UTC
        return localDt.addHours(3);
    }
    
    public static List<AA_ComboSlot> getComboAvailableSlots(List<Id> serviceIds, Date targetDate) {
        List<AA_ComboSlot> combos = new List<AA_ComboSlot>();
        if (serviceIds == null || serviceIds.isEmpty()) return combos;
        
        if (serviceIds.size() == 1) {
            List<AA_AvailableSlot> slots = getAvailableSlots(serviceIds[0], targetDate);
            for (AA_AvailableSlot s : slots) {
                combos.add(new AA_ComboSlot(s.slotTime, new List<AA_AvailableSlot>{s}));
            }
            return combos;
        }
        
        if (serviceIds.size() == 2) {
            List<AA_AvailableSlot> slotsA = getAvailableSlots(serviceIds[0], targetDate);
            List<AA_AvailableSlot> slotsB = getAvailableSlots(serviceIds[1], targetDate);
            
            for (AA_AvailableSlot a : slotsA) {
                for (AA_AvailableSlot b : slotsB) {
                    if (a.endTime == b.slotTime) {
                        combos.add(new AA_ComboSlot(a.slotTime, new List<AA_AvailableSlot>{a, b}));
                    }
                }
            }
        }
        
        return combos;
    }
    
}