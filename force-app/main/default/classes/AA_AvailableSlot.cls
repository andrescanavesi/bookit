public class AA_AvailableSlot {
   @AuraEnabled public Datetime slotTime;        // Almacenado en UTC
    @AuraEnabled public Datetime endTime;         // Hora de fin calculada
    @AuraEnabled public Integer durationMinutes;  // Duración del servicio en minutos
    @AuraEnabled public String slotTimeFormatted; // Almacenado como GMT-3 String
    @AuraEnabled public Id employeeId;
    @AuraEnabled public String employeeName;
    @AuraEnabled public String serviceName;
    @AuraEnabled public Id serviceId;
    @AuraEnabled public String branchName;
    @AuraEnabled public Id branchId;
    @AuraEnabled public String compositeId;
    @AuraEnabled public String slotDayString;
    @AuraEnabled public String slotTimeString;
    
    @AuraEnabled public String dayNumber;
    @AuraEnabled public String dayOfTheWeek;
    @AuraEnabled public String monthName;
    @AuraEnabled public String hourAmPm;
    @AuraEnabled public String hour24;
    @AuraEnabled public String fullDateTime;
    
    
    public AA_AvailableSlot(Datetime slotTime, Id employeeId, String employeeName, String serviceName, 
                            Id serviceId, String branchName, Id branchId, Integer durationMinutes) {
        this.slotTime = slotTime;
        this.durationMinutes = durationMinutes != null ? durationMinutes : 0;
        this.endTime = slotTime != null ? slotTime.addMinutes(this.durationMinutes) : null;
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
                            'a05gL00000GUkNZQA1', 'Pocitos', 'a05gL00000GUkNZQA1', 60);
        System.debug(slot.fullDateTime);
    }
    
}