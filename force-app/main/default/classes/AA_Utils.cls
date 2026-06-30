public class AA_Utils {
    
    public static final String TIMEZONE = 'GMT-03:00';
    
    public static Map<Integer, String> SPANISH_MONTHS = new Map<Integer, String>{
        1 => 'Enero', 2 => 'Febrero', 3 => 'Marzo', 4 => 'Abril', 
            5 => 'Mayo', 6 => 'Junio', 7 => 'Julio', 8 => 'Agosto', 
            9 => 'Septiembre', 10 => 'Octubre', 11 => 'Noviembre', 12 => 'Diciembre'
            };
                
    public static  Map<String, String> SPANISH_DAYS = new Map<String, String>{
        'Monday' => 'Lunes', 'Tuesday' => 'Martes', 'Wednesday' => 'Miércoles',
        'Thursday' => 'Jueves', 'Friday' => 'Viernes', 'Saturday' => 'Sábado', 'Sunday' => 'Domingo'
    };

    public static Map<String, String> SPANISH_STATUS = new Map<String, String>{
        'Pending' => 'Pendiente',
        'Confirmed' => 'Confirmado',
        'Cancelled' => 'Cancelado',
        'Rescheduled' => 'Reagendado',
        'No Show' => 'No se Presenta',
        'Done' => 'Hecho'
    };

    public static String translateStatus(String status) {
        if (String.isNotBlank(status) && SPANISH_STATUS.containsKey(status)) {
            return SPANISH_STATUS.get(status);
        }
        return status != null ? status : '';
    }
}