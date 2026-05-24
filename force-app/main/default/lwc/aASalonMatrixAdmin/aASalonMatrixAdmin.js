import { LightningElement, track } from 'lwc'; 

export default class AASalonMatrixAdmin extends LightningElement {
 
    // Datos simulados (Mock Data)
    mockEmployees = [
        { id: 'E1', name: 'Victoria', color: '#B23A3A' }, // Rojo
        { id: 'E2', name: 'Martin', color: '#3A70A1' },   // Azul
        { id: 'E3', name: 'Paolo', color: '#5A8A4F' }     // Verde
    ];

    mockAppointments = [
        { id: 'A1', employeeId: 'E1', startTime: '09:00', duration: 60, customer: 'Lucia P.', service: 'Balayage' },
        { id: 'A2', employeeId: 'E2', startTime: '10:30', duration: 30, customer: 'Juan M.', service: 'Corte Hombre' },
        { id: 'A3', employeeId: 'E1', startTime: '11:00', duration: 90, customer: 'Sofia C.', service: 'Alisado' },
        { id: 'A4', employeeId: 'E3', startTime: '14:30', duration: 60, customer: 'Diego R.', service: 'Masaje Capilar' }
    ];

    @track gridHeaders = [];
    @track gridRows = [];

    connectedCallback() {
        this.generateMatrix();
    }

    // Función auxiliar para convertir "09:30" a minutos (570) y facilitar el cálculo
    timeToMins(timeStr) {
        const [hours, minutes] = timeStr.split(':').map(Number);
        return (hours * 60) + minutes;
    }

    generateMatrix() {
        // 1. Armamos los encabezados (la primera columna vacía + los empleados)
        this.gridHeaders = [
            { id: 'TIME_COL', label: 'Hora', isTime: true },
            ...this.mockEmployees.map(emp => ({
                id: emp.id,
                label: emp.name,
                isTime: false
            }))
        ];

        // 2. Generamos los bloques de tiempo (slots) de 09:00 a 18:00 cada 30 min
        const startHour = 9;
        const endHour = 18;
        const timeSlots = [];
        
        for (let h = startHour; h <= endHour; h++) {
            const hourStr = String(h).padStart(2, '0');
            timeSlots.push(`${hourStr}:00`);
            if (h !== endHour) {
                timeSlots.push(`${hourStr}:30`);
            }
        }

        // 3. Cruzamos el tiempo con los empleados para generar las celdas
        this.gridRows = timeSlots.map(timeLabel => {
            const slotMins = this.timeToMins(timeLabel);
            
            // Creamos las celdas de la fila (empezando por la etiqueta de la hora)
            let cells = [
                { id: `TIME_${timeLabel}`, isTimeLabel: true, label: timeLabel }
            ];

            // Revisamos la disponibilidad de cada empleado en este bloque de 30 mins
            this.mockEmployees.forEach(emp => {
                
                // Buscamos si el empleado tiene una cita que cubra estos minutos
                const activeAppt = this.mockAppointments.find(appt => {
                    if (appt.employeeId !== emp.id) return false;
                    
                    const apptStartMins = this.timeToMins(appt.startTime);
                    const apptEndMins = apptStartMins + appt.duration;
                    
                    // El slot está ocupado si su inicio cae dentro de la cita
                    return slotMins >= apptStartMins && slotMins < apptEndMins;
                });

                if (activeAppt) {
                    // Si hay cita, determinamos si es el primer bloque (para poner el texto)
                    const isStart = this.timeToMins(activeAppt.startTime) === slotMins;
                    
                    cells.push({
                        id: `${emp.id}_${timeLabel}`,
                        isTimeLabel: false,
                        isOccupied: true,
                        isStartBlock: isStart,
                        data: isStart ? activeAppt : null,
                        style: `background-color: ${emp.color};`, // Inyectamos el color del empleado
                        cssClass: isStart ? 'cell-appt cell-appt-start' : 'cell-appt cell-appt-body'
                    });
                } else {
                    // Si no hay cita, el hueco está libre
                    cells.push({
                        id: `${emp.id}_${timeLabel}`,
                        isTimeLabel: false,
                        isOccupied: false,
                        time: timeLabel,
                        empId: emp.id,
                        cssClass: 'cell-free'
                    });
                }
            });

            return { id: `ROW_${timeLabel}`, cells: cells };
        });
    }

    // Evento para cuando la administradora hace clic en un hueco vacío
    handleEmptySlotClick(event) {
        const time = event.currentTarget.dataset.time;
        const empId = event.currentTarget.dataset.empid;
        const empName = this.mockEmployees.find(e => e.id === empId).name;
        
        alert(`Abrir modal de nueva cita para ${empName} a las ${time} hs.`);
        // Aquí conectaremos el formulario de creación más adelante
    }
}