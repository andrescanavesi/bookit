public with sharing class AA_WeeklyMatrixController {

    public class WeeklyMatrixResponse {
        @AuraEnabled public Map<String, BranchDayHour> branchHours { get; set; }
        @AuraEnabled public List<String> timeSlots { get; set; }
        @AuraEnabled public Map<String, Map<String, SlotCapacity>> matrix { get; set; }
        @AuraEnabled public String branchId { get; set; }
        @AuraEnabled public String branchName { get; set; }
        
        public WeeklyMatrixResponse() {
            this.branchHours = new Map<String, BranchDayHour>();
            this.timeSlots = new List<String>();
            this.matrix = new Map<String, Map<String, SlotCapacity>>();
        }
    }

    public class BranchDayHour {
        @AuraEnabled public String openTime { get; set; }
        @AuraEnabled public String closeTime { get; set; }
    }

    public class SlotCapacity {
        @AuraEnabled public Integer occupied { get; set; }
        @AuraEnabled public Integer capacity { get; set; }
        @AuraEnabled public String status { get; set; } // Libre, Parcial, Lleno
        
        public SlotCapacity() {
            this.occupied = 0;
            this.capacity = 0;
            this.status = 'Inactivo';
        }
    }

    @AuraEnabled(cacheable=true)
    public static WeeklyMatrixResponse getWeeklyOccupancy(Date targetDate) {
        WeeklyMatrixResponse response = new WeeklyMatrixResponse();
        
        // 1. Get Branch (assume first one for now)
        List<AA_Business_Branch__c> branches = [SELECT Id, Name FROM AA_Business_Branch__c LIMIT 1];
        if (branches.isEmpty()) return response;
        AA_Business_Branch__c branch = branches[0];
        response.branchId = branch.Id;
        response.branchName = branch.Name;

        // Determine Start of Week (Monday)
        Date startOfWeek = targetDate.toStartOfWeek();
        Datetime dt = Datetime.newInstance(startOfWeek.year(), startOfWeek.month(), startOfWeek.day());
        String dayOfWeekStr = dt.format('EEEE'); // e.g., 'Sunday'
        if (dayOfWeekStr == 'Sunday') {
            startOfWeek = startOfWeek.addDays(1);
        } else if (dayOfWeekStr != 'Monday') {
            Integer daysToSubtract = 0;
            if (dayOfWeekStr == 'Tuesday') daysToSubtract = 1;
            else if (dayOfWeekStr == 'Wednesday') daysToSubtract = 2;
            else if (dayOfWeekStr == 'Thursday') daysToSubtract = 3;
            else if (dayOfWeekStr == 'Friday') daysToSubtract = 4;
            else if (dayOfWeekStr == 'Saturday') daysToSubtract = 5;
            startOfWeek = startOfWeek.addDays(-daysToSubtract);
        }
        Date endOfWeek = startOfWeek.addDays(6); // Sunday
        
        // 2. Get Branch Working Hours
        List<AA_Branch_Working_Hour__c> bwhs = [SELECT Day_Of_Week__c, Open_Time__c, Close_Time__c FROM AA_Branch_Working_Hour__c WHERE Business_Branch__c = :branch.Id];
        
        Time minOpenTime = Time.newInstance(23, 59, 0, 0);
        Time maxCloseTime = Time.newInstance(0, 0, 0, 0);
        
        for (AA_Branch_Working_Hour__c bwh : bwhs) {
            BranchDayHour bdh = new BranchDayHour();
            bdh.openTime = formatTime(bwh.Open_Time__c);
            bdh.closeTime = formatTime(bwh.Close_Time__c);
            response.branchHours.put(bwh.Day_Of_Week__c, bdh);
            
            if (bwh.Open_Time__c < minOpenTime) minOpenTime = bwh.Open_Time__c;
            if (bwh.Close_Time__c > maxCloseTime) maxCloseTime = bwh.Close_Time__c;
        }

        // Generate Time Slots (every 30 mins)
        Time currentSlot = minOpenTime;
        while (currentSlot < maxCloseTime) {
            response.timeSlots.add(formatTime(currentSlot));
            currentSlot = currentSlot.addMinutes(30);
        }

        // 3. Employee Working Hours (Base Capacity)
        List<AA_Employee_Working_Hour__c> ewhs = [SELECT Employee__c, Day_Of_Week__c, Start_Hour__c, End_Hour__c, Start_Default_Break_Hour__c, End_Default_Break_Hour__c FROM AA_Employee_Working_Hour__c WHERE Employee__r.Business_Branch__c = :branch.Id];
        
        // Pre-build matrix structure
        Map<String, String> dateToDayOfWeek = new Map<String, String>();
        for (Integer i = 0; i < 7; i++) {
            Date d = startOfWeek.addDays(i);
            String dateStr = String.valueOf(d);
            String dow = getEnglishDayOfWeek(d);
            dateToDayOfWeek.put(dateStr, dow);
            
            if (response.branchHours.containsKey(dow)) {
                Map<String, SlotCapacity> dayMap = new Map<String, SlotCapacity>();
                for (String tSlot : response.timeSlots) {
                    dayMap.put(tSlot, new SlotCapacity());
                }
                response.matrix.put(dateStr, dayMap);
            }
        }

        // Calculate capacity per slot based on Employee Working Hours
        for (AA_Employee_Working_Hour__c ewh : ewhs) {
            String dow = ewh.Day_Of_Week__c;
            for (String dateStr : response.matrix.keySet()) {
                if (dateToDayOfWeek.get(dateStr) == dow) {
                    Map<String, SlotCapacity> dayMap = response.matrix.get(dateStr);
                    for (String tSlot : dayMap.keySet()) {
                        Time t = parseTime(tSlot);
                        Boolean isWorking = (t >= ewh.Start_Hour__c && t < ewh.End_Hour__c);
                        Boolean isBreak = false;
                        if (ewh.Start_Default_Break_Hour__c != null && ewh.End_Default_Break_Hour__c != null) {
                            if (t >= ewh.Start_Default_Break_Hour__c && t < ewh.End_Default_Break_Hour__c) {
                                isBreak = true;
                            }
                        }
                        if (isWorking && !isBreak) {
                            dayMap.get(tSlot).capacity++;
                        }
                    }
                }
            }
        }

        // 4. Appointments & Absences
        Datetime weekStartDt = Datetime.newInstance(startOfWeek.year(), startOfWeek.month(), startOfWeek.day(), 0, 0, 0);
        Datetime weekEndDt = Datetime.newInstance(endOfWeek.year(), endOfWeek.month(), endOfWeek.day(), 23, 59, 59);

        List<AA_Appointment__c> appointments = [
            SELECT Start_Date_Time__c, End_Date_Time__c, Employee__c 
            FROM AA_Appointment__c 
            WHERE Service__r.Business_Branch__c = :branch.Id 
            AND Start_Date_Time__c >= :weekStartDt 
            AND Start_Date_Time__c <= :weekEndDt
            AND Status__c != 'Canceled'
        ];

        List<AA_Employee_Absence__c> absences = [
            SELECT Start_Date_Time__c, End_Date_Time__c, Employee__c 
            FROM AA_Employee_Absence__c 
            WHERE Employee__r.Business_Branch__c = :branch.Id 
            AND Start_Date_Time__c >= :weekStartDt 
            AND Start_Date_Time__c <= :weekEndDt
        ];

        // Process Appointments
        for (AA_Appointment__c app : appointments) {
            markOccupied(app.Start_Date_Time__c, app.End_Date_Time__c, response.matrix);
        }
        
        for (AA_Employee_Absence__c abs : absences) {
            markOccupied(abs.Start_Date_Time__c, abs.End_Date_Time__c, response.matrix);
        }

        // 5. Compute Status
        for (String dateStr : response.matrix.keySet()) {
            Map<String, SlotCapacity> dayMap = response.matrix.get(dateStr);
            for (String tSlot : dayMap.keySet()) {
                SlotCapacity sc = dayMap.get(tSlot);
                if (sc.capacity == 0) {
                    sc.status = 'Inactivo';
                } else if (sc.occupied == 0) {
                    sc.status = 'Libre';
                } else if (sc.occupied >= sc.capacity) {
                    sc.status = 'Lleno';
                } else {
                    sc.status = 'Parcial';
                }
            }
        }

        return response;
    }

    private static void markOccupied(Datetime startDt, Datetime endDt, Map<String, Map<String, SlotCapacity>> matrix) {
        // Assume timezone is GMT-3
        startDt = startDt.addHours(-3);
        endDt = endDt.addHours(-3);
        
        Date d = startDt.date();
        String dateStr = String.valueOf(d);
        
        if (matrix.containsKey(dateStr)) {
            Map<String, SlotCapacity> dayMap = matrix.get(dateStr);
            
            Time currTime = startDt.time();
            Time endTime = endDt.time();
            
            Integer min = currTime.minute();
            if (min >= 30) min = 30; else min = 0;
            currTime = Time.newInstance(currTime.hour(), min, 0, 0);
            
            while (currTime < endTime) {
                String tSlot = formatTime(currTime);
                if (dayMap.containsKey(tSlot)) {
                    dayMap.get(tSlot).occupied++;
                }
                currTime = currTime.addMinutes(30);
            }
        }
    }

    private static String formatTime(Time t) {
        String h = String.valueOf(t.hour()).leftPad(2, '0');
        String m = String.valueOf(t.minute()).leftPad(2, '0');
        return h + ':' + m;
    }
    
    private static Time parseTime(String tStr) {
        List<String> parts = tStr.split(':');
        return Time.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), 0, 0);
    }
    
    private static String getEnglishDayOfWeek(Date d) {
        Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day());
        return dt.format('EEEE');
    }
}