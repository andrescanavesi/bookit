@IsTest
private class AA_UtilsTest {
    
    @IsTest
    static void testTranslateStatus() {
        System.assertEquals('Pendiente', AA_Utils.translateStatus('Pending'), 'Should translate Pending');
        System.assertEquals('Confirmado', AA_Utils.translateStatus('Confirmed'), 'Should translate Confirmed');
        System.assertEquals('Cancelado', AA_Utils.translateStatus('Cancelled'), 'Should translate Cancelled');
        System.assertEquals('Reagendado', AA_Utils.translateStatus('Rescheduled'), 'Should translate Rescheduled');
        System.assertEquals('No se Presenta', AA_Utils.translateStatus('No Show'), 'Should translate No Show');
        System.assertEquals('Hecho', AA_Utils.translateStatus('Done'), 'Should translate Done');
        
        System.assertEquals('Unknown', AA_Utils.translateStatus('Unknown'), 'Should return original if unknown');
        System.assertEquals('', AA_Utils.translateStatus(null), 'Should return empty string if null');
    }
    
    @IsTest
    static void testConstants() {
        System.assertEquals('GMT-03:00', AA_Utils.TIMEZONE, 'Timezone should be GMT-03:00');
        System.assert(AA_Utils.SPANISH_MONTHS.containsKey(1), 'Should contain month 1');
        System.assert(AA_Utils.SPANISH_DAYS.containsKey('Monday'), 'Should contain Monday');
    }
}
