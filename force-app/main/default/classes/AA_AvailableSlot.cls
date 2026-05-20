public class AA_AvailableSlot {
    // Wrapper for the final JSON response to WhatsApp
    
    public Datetime slotTime;        // Stored in UTC (Native Apex format)
    public String slotTimeFormatted; // Stored as GMT-3 String for display
    public Id employeeId;
    public String employeeName;
    public String serviceName;
    public Id serviceId;
    public String branchName;
    public Id branchId;
    public String compositeId;
    public String slotDayString;
    public String slotTimeString;
    
    public String dayNumber;
    public String dayOfTheWeek;
    public String monthName;
    public String hourAmPm;
    public String hour24;
    public String fullDateTime;
    
    
    public AA_AvailableSlot(Datetime slotTime, Id employeeId, String employeeName, String serviceName, 
                            Id serviceId, String branchName, Id branchId) {
        this.slotTime = slotTime;
        this.employeeId = employeeId;
        this.employeeName = employeeName;
        this.serviceName = serviceName;
        this.serviceId = serviceId;
        this.branchName = branchName;
        this.branchId = branchId;
        
        // Convert the UTC Datetime to a GMT-3 String immediately
        // Format: 'yyyy-MM-dd HH:mm:ss' (Adjust the pattern as needed)
        if (slotTime != null) {
            String timeZone = 'GMT-03:00';
            this.slotTimeFormatted = slotTime.format('yyyy-MM-dd HH:mm:ss', AA_Utils.TIMEZONE);
            this.slotDayString = slotTime.format('yyyy-MM-dd', AA_Utils.TIMEZONE);
            this.slotTimeString = slotTime.format('HH:mm', AA_Utils.TIMEZONE);
            
            Map<Integer, String> spanishMonths = new Map<Integer, String>{
                1 => 'Enero', 2 => 'Febrero', 3 => 'Marzo', 4 => 'Abril', 
                    5 => 'Mayo', 6 => 'Junio', 7 => 'Julio', 8 => 'Agosto', 
                    9 => 'Septiembre', 10 => 'Octubre', 11 => 'Noviembre', 12 => 'Diciembre'
                    };
                        
                        Map<String, String> spanishDays = new Map<String, String>{
                            'Monday' => 'Lunes', 'Tuesday' => 'Martes', 'Wednesday' => 'Miércoles',
                                'Thursday' => 'Jueves', 'Friday' => 'Viernes', 'Saturday' => 'Sábado', 'Sunday' => 'Domingo'
                                };
                                    
            this.dayNumber = slotTime.format('d');
            this.dayOfTheWeek = AA_Utils.SPANISH_DAYS.get(slotTime.format('EEEE', AA_Utils.TIMEZONE));
            this.monthName = AA_Utils.SPANISH_MONTHS.get(slotTime.month());
            this.hourAmPm = slotTime.format('h:mm a', AA_Utils.TIMEZONE);
            this.hour24 = slotTime.format('H:mm', AA_Utils.TIMEZONE);
            
            //this.fullDateTime = this.dayOfTheWeek+' '+this.dayNumber+' de '+this.monthName+', '+this.hour24+'Hs';
			// must be less than 24 chars due to whastapp restriction
            this.fullDateTime = this.dayOfTheWeek+' '+this.dayNumber+', '+this.hour24+'Hs'; 
        }
        this.compositeId = 'SLOT|'+employeeId+'|'+this.employeeName+'|'+this.serviceId+'|'
            +this.serviceName+'|'+this.branchName+'|'+this.slotDayString+'|'+slotTimeString;
    }
    
    // AA_AvailableSlot.testSlot();
    public static void testSlot(){
        AA_AvailableSlot slot = new AA_AvailableSlot(Datetime.now(), 'a05gL00000GUkNZQA1', 'Juan', 'Masaje', 
                            'a05gL00000GUkNZQA1', 'Pocitos', 'a05gL00000GUkNZQA1');
        System.debug(slot.fullDateTime);
    }
    
}