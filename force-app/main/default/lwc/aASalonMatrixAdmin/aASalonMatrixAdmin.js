import { LightningElement, track, wire } from 'lwc';
import getMatrixData from '@salesforce/apex/AA_SalonAppointmentsController.getMatrixData';

export default class AASalonMatrixAdmin extends LightningElement {
    
    @track weekDays = [];
    @track selectedDate = ''; // Formato YYYY-MM-DD
    @track gridHeaders = [];
    @track gridRows = [];

    // Arrays dinámicos que llenará la base de datos
    @track activeEmployees = [];
    @track activeAppointments = [];

    // Mantenemos la paleta corporativa elegante para asignar dinámicamente a los empleados
    employeeColors = ['#B23A3A', '#D4A017', '#3A70A1', '#5A8A4F', '#6B4F8E', '#A15C3A'];

    connectedCallback() {
        this.initWeekDays(); // Inicializa las 7 tarjetas de fechas
    }

    // 1. GENERAR LOS PRÓXIMOS 7 DÍAS (Igual a tu versión visual anterior)
    initWeekDays() {
        const today = new Date();
        const days = [];
        const DOW = ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'];
        const MONTHS = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SET', 'OCT', 'NOV', 'DIC'];

        for (let i = 0; i < 7; i++) {
            const d = new Date(today);
            d.setDate(today.getDate() + i);
            const isoDate = d.toISOString().split('T')[0];

            if (i === 0) {
                this.selectedDate = isoDate; // Hoy por defecto
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

    // 2. CONEXIÓN AL BACKEND: Wire reactivo al cambio de fecha
    @wire(getMatrixData, { selectedDate: '$selectedDate' })
    wiredMatrixData({ error, data }) {
        console.info('wiredMatrixData, date: '+this.selectedDate);
        if (data) {
            // A. Procesamos los empleados reales asignándoles un color de la paleta
            let colorIndex = 0;
            this.activeEmployees = data.employees.map(emp => {
                const color = this.employeeColors[colorIndex % this.employeeColors.length];
                colorIndex++;
                return {
                    id: emp.Id,
                    name: emp.Name,
                    color: color
                };
            });

            // B. Procesamos las citas reales mapeando los campos
            this.activeAppointments = data.appointments.map(appt => {
                const dt = new Date(appt.Start_Date_Time__c);
                const durationMins = appt.Service__r?.Duration_Minutes__c || 30;
                
                // Calculamos la fecha/hora de fin
                const endDt = new Date(dt.getTime() + durationMins * 60000);
                
                const startTimeStr = dt.toLocaleTimeString('es-UY', { hour: '2-digit', minute: '2-digit', hour12: false });
                const endTimeStr = endDt.toLocaleTimeString('es-UY', { hour: '2-digit', minute: '2-digit', hour12: false });
                
                const firstName = appt.Customer__r?.First_Name__c || '';
                const lastName = appt.Customer__r?.Last_Name__c || '';
                
                // Formateamos el precio (Ajusta 'Price__c' si tu campo se llama distinto)
                const rawPrice = appt.Amount__c;
                const formattedPrice = rawPrice ? `$${rawPrice}` : 'Sin costo';

                return {
                    id: appt.Id,
                    employeeId: appt.Employee__c,
                    startTime: startTimeStr,
                    duration: durationMins,
                    customer: `${firstName} ${lastName}`.trim() || 'Sin Nombre',
                    service: appt.Service__r?.Name || 'Servicio',
                    // NUEVAS PROPIEDADES PARA LA UI
                    timeRange: `${startTimeStr} - ${endTimeStr}`,
                    priceText: formattedPrice
                };
            });

            // C. Una vez que la data real está lista y estructurada, dibujamos la matriz
            this.generateMatrix();

        } else if (error) {
            console.error('Error al recuperar información de la matriz:', JSON.stringify(error));
        }
    }

    // 3. CAMBIAR DE DÍA (Dispara el @wire automáticamente al alterar la propiedad reactiva)
    handleDateSelect(event) {
        const selected = event.currentTarget.dataset.date;
        this.selectedDate = selected;
        console.info('handleDateSelect, date: '+this.selectedDate);

        this.weekDays = this.weekDays.map(day => ({
            ...day,
            cssClass: day.dateKey === selected ? 'date-card date-card--active' : 'date-card'
        }));
        //console.info(JSON.stringify(this.weekDays, null, 2));
    }

    timeToMins(timeStr) {
        const [hours, minutes] = timeStr.split(':').map(Number);
        return (hours * 60) + minutes;
    }

    // 4. GENERAR MATRIZ (Idéntica matemática, pero alimentada por arrays del servidor)
    generateMatrix() {
        console.info('generateMatrix, selectedDate: '+this.selectedDate);
        this.gridHeaders = [
            { id: 'TIME_COL', label: 'Hora', isTime: true, cssClass: 'th-time' },
            ...this.activeEmployees.map(emp => ({
                id: emp.id,
                label: emp.name,
                isTime: false,
                dotStyle: `background-color: ${emp.color};`,
                cssClass: 'th-emp'
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

            this.activeEmployees.forEach(emp => {
                
                // Buscamos si hay una cita real que pise este slot de tiempo
                const activeAppt = this.activeAppointments.find(appt => {
                    if (appt.employeeId !== emp.id) return false;
                    
                    const apptStartMins = this.timeToMins(appt.startTime);
                    const apptEndMins = apptStartMins + appt.duration;
                    
                    return slotMins >= apptStartMins && slotMins < apptEndMins;
                });

                if (activeAppt) {
                    const isStart = this.timeToMins(activeAppt.startTime) === slotMins;
                    
                    cells.push({
                        id: `${emp.id}_${timeLabel}`,
                        isTimeLabel: false,
                        isOccupied: true,
                        isStartBlock: isStart,
                        data: isStart ? activeAppt : null,
                        style: `background-color: ${emp.color};`,
                        cssClass: isStart ? 'cell-appt cell-appt-start' : 'cell-appt cell-appt-body'
                    });
                } else {
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

    handleEmptySlotClick(event) {
        const time = event.currentTarget.dataset.time;
        const empId = event.currentTarget.dataset.empid;
        const empName = this.activeEmployees.find(e => e.id === empId).name;
        
        // El alert ahora mostrará la fecha real seleccionada del calendario en formato YYYY-MM-DD
        alert(`Abrir modal de nueva cita para ${empName} el día ${this.selectedDate} a las ${time} hs.`);
    }
}