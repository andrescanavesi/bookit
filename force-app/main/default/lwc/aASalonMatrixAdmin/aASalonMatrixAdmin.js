import { LightningElement, track } from 'lwc';

export default class AASalonMatrixAdmin extends LightningElement {
    
    @track weekDays = [];
    @track selectedDate = '';
    @track gridHeaders = [];
    @track gridRows = [];

   // 1. EL NUEVO EQUIPO
    mockEmployees = [
        { id: 'E1', name: 'Silvina', color: '#B23A3A' },   // Rojo óxido
        { id: 'E2', name: 'Dahiana', color: '#D4A017' },   // Mostaza
        { id: 'E3', name: 'Sophie', color: '#3A70A1' },    // Azul grisáceo
        { id: 'E4', name: 'Yamila', color: '#5A8A4F' },    // Verde salvia
        { id: 'E5', name: 'Soledad', color: '#6B4F8E' },   // Violeta apagado
        { id: 'E6', name: 'Agustina', color: '#A15C3A' }   // Terracota
    ];

    // Mantenemos la variable limpia, la llenaremos en el connectedCallback
    mockAppointments = [];

    connectedCallback() {
        this.initWeekDays();
        this.initMockData();
        this.generateMatrix();
    }

    // 1. GENERAR LOS PRÓXIMOS 7 DÍAS
    initWeekDays() {
        const today = new Date();
        const days = [];
        const DOW = ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'];
        const MONTHS = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SET', 'OCT', 'NOV', 'DIC'];

        for (let i = 0; i < 7; i++) {
            const d = new Date(today);
            d.setDate(today.getDate() + i);

            // Formato ISO YYYY-MM-DD para usar como ID único
            const isoDate = d.toISOString().split('T')[0];

            if (i === 0) {
                this.selectedDate = isoDate; // Seleccionamos "Hoy" por defecto
            }

            days.push({
                dateKey: isoDate,
                dayOfWeek: DOW[d.getDay()],
                dayNumber: d.getDate(),
                month: MONTHS[d.getMonth()],
                cssClass: i === 0 ? 'date-card date-card--active' : 'date-card'
            });
        }
        this.weekDays = days;
    }

    // 2. LOS TURNOS SIMULADOS DISTRIBUIDOS
    initMockData() {
        if (this.weekDays.length < 2) return;
        const hoyStr = this.weekDays[0].dateKey;
        const mananaStr = this.weekDays[1].dateKey;

        this.mockAppointments = [
            // Turnos de HOY
            { id: 'A1', date: hoyStr, employeeId: 'E1', startTime: '09:00', duration: 90, customer: 'Lucia P.', service: 'Balayage' },
            { id: 'A2', date: hoyStr, employeeId: 'E2', startTime: '10:00', duration: 60, customer: 'Juan M.', service: 'Corte y Lavado' },
            { id: 'A3', date: hoyStr, employeeId: 'E4', startTime: '10:30', duration: 30, customer: 'Carla T.', service: 'Perfilado Cejas' },
            { id: 'A4', date: hoyStr, employeeId: 'E6', startTime: '14:00', duration: 120, customer: 'Marta G.', service: 'Alisado Keratina' },
            { id: 'A5', date: hoyStr, employeeId: 'E3', startTime: '15:30', duration: 60, customer: 'Romina L.', service: 'Nutrición' },
            { id: 'A6', date: hoyStr, employeeId: 'E5', startTime: '17:00', duration: 60, customer: 'Ana S.', service: 'Manicura Semipermanente' },
            { id: 'A7', date: hoyStr, employeeId: 'E1', startTime: '16:30', duration: 30, customer: 'Valeria C.', service: 'Corte Mujer' },

            // Turnos de MAÑANA
            { id: 'B1', date: mananaStr, employeeId: 'E3', startTime: '09:00', duration: 60, customer: 'Sofia C.', service: 'Peinado Evento' },
            { id: 'B2', date: mananaStr, employeeId: 'E2', startTime: '11:00', duration: 90, customer: 'Diego R.', service: 'Coloración' },
            { id: 'B3', date: mananaStr, employeeId: 'E4', startTime: '13:00', duration: 60, customer: 'Elena B.', service: 'Maquillaje' },
            { id: 'B4', date: mananaStr, employeeId: 'E5', startTime: '14:30', duration: 90, customer: 'Julia M.', service: 'Esculpido Acrílico' },
            { id: 'B5', date: mananaStr, employeeId: 'E6', startTime: '16:00', duration: 60, customer: 'Carmen V.', service: 'Corte y Brushing' }
        ];
    }
    // 3. CAMBIAR DE DÍA AL HACER CLIC
    handleDateSelect(event) {
        const selected = event.currentTarget.dataset.date;
        this.selectedDate = selected;

        // Actualizamos la clase CSS para pintar de negro el seleccionado
        this.weekDays = this.weekDays.map(day => ({
            ...day,
            cssClass: day.dateKey === selected ? 'date-card date-card--active' : 'date-card'
        }));

        // Re-dibujamos la grilla para este nuevo día
        this.generateMatrix();
    }

    timeToMins(timeStr) {
        const [hours, minutes] = timeStr.split(':').map(Number);
        return (hours * 60) + minutes;
    }

    // 4. GENERAR MATRIZ (AHORA FILTRADA POR FECHA)
    generateMatrix() {
        this.gridHeaders = [
            { id: 'TIME_COL', label: 'Hora', isTime: true, cssClass: 'th-time' },
            ...this.mockEmployees.map(emp => ({
                id: emp.id, label: emp.name, isTime: false,
                dotStyle: `background-color: ${emp.color};`, cssClass: 'th-emp'
            }))
        ];

        const timeSlots = [];
        for (let h = 9; h <= 18; h++) {
            const hourStr = String(h).padStart(2, '0');
            timeSlots.push(`${hourStr}:00`);
            if (h !== 18) timeSlots.push(`${hourStr}:30`);
        }

        this.gridRows = timeSlots.map(timeLabel => {
            const slotMins = this.timeToMins(timeLabel);
            let cells = [{ id: `TIME_${timeLabel}`, isTimeLabel: true, label: timeLabel }];

            this.mockEmployees.forEach(emp => {
                // FILTRO CLAVE: Solo buscamos citas del selectedDate y del empleado
                const activeAppt = this.mockAppointments.find(appt => {
                    if (appt.date !== this.selectedDate) return false;
                    if (appt.employeeId !== emp.id) return false;
                    
                    const apptStartMins = this.timeToMins(appt.startTime);
                    const apptEndMins = apptStartMins + appt.duration;
                    return slotMins >= apptStartMins && slotMins < apptEndMins;
                });

                if (activeAppt) {
                    const isStart = this.timeToMins(activeAppt.startTime) === slotMins;
                    cells.push({
                        id: `${emp.id}_${timeLabel}`,
                        isTimeLabel: false, isOccupied: true, isStartBlock: isStart,
                        data: isStart ? activeAppt : null,
                        style: `background-color: ${emp.color};`,
                        cssClass: isStart ? 'cell-appt cell-appt-start' : 'cell-appt cell-appt-body'
                    });
                } else {
                    cells.push({
                        id: `${emp.id}_${timeLabel}`,
                        isTimeLabel: false, isOccupied: false,
                        time: timeLabel, empId: emp.id,
                        cssClass: 'cell-free'
                    });
                }
            });
            return { id: `ROW_${timeLabel}`, cells: cells };
        });
    }

    handleEmptySlotClick(event) {
        const time = event.currentTarget.dataset.time;
        const empId = event.currentTarget.dataset.empid;
        const empName = this.mockEmployees.find(e => e.id === empId).name;
        alert(`Abrir modal de nueva cita para ${empName} el ${this.selectedDate} a las ${time} hs.`);
    }
}