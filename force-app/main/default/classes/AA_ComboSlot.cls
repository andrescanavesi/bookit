public class AA_ComboSlot {
    @AuraEnabled public Datetime startTime;
    @AuraEnabled public String comboSlotId;
    @AuraEnabled public String timeFormatted; // e.g. "10:30Hs"
    @AuraEnabled public String fullDateTime;
    @AuraEnabled public List<AA_AvailableSlot> slots;
    
    public AA_ComboSlot(Datetime startTime, List<AA_AvailableSlot> slots) {
        this.startTime = startTime;
        this.slots = slots;
        
        if (startTime != null) {
            this.timeFormatted = startTime.format('HH:mm', AA_Utils.TIMEZONE);
            
            String dayNumber = startTime.format('d');
            String dayOfTheWeek = AA_Utils.SPANISH_DAYS.get(startTime.format('EEEE', AA_Utils.TIMEZONE));
            this.fullDateTime = dayOfTheWeek + ' ' + dayNumber + ', ' + this.timeFormatted + 'Hs';
        }
        
        // Generar un ID único para el combo
        List<String> slotIds = new List<String>();
        for (AA_AvailableSlot slot : slots) {
            slotIds.add(slot.compositeId);
        }
        this.comboSlotId = 'COMBO|' + String.join(slotIds, '|');
    }
}
