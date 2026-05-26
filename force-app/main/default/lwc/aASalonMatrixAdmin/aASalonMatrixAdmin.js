import { LightningElement, track, wire } from 'lwc';
import getMatrixData from '@salesforce/apex/AA_SalonAppointmentsController.getMatrixData';

export default class AASalonMatrixAdmin extends LightningElement {
    
    @track weekDays = [];
    @track selectedDate = ''; 
    @track gridHeaders = [];
    @track gridRows = [];

    @track activeEmployees = [];
    @track activeAppointments = [];
    @track activeAbsences = []; // NUEVO
    @track activeWorkingHours = []; // NUEVO

    // Opciones para los comboboxes del formulario
    @track customerOptions = [];
    @track serviceOptions = [];

    // NUEVO: Almacenamiento crudo para filtrado dinámico
    rawAllServices = [];
    rawEmployeeServices = [];

    employeeColors = ['#B23A3A', '#D4A017', '#3A70A1', '#5A8A4F', '#6B4F8E', '#A15C3A'];

    connectedCallback() {
        this.initWeekDays();
    }

    initWeekDays() {
        const today = new Date();
        const days = [];
        const DOW = ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'];
        const MONTHS = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SET', 'OCT', 'NOV', 'DIC'];

        for (let i = 0; i < 7; i++) {
            const d = new Date(today);
            d.setDate(today.getDate() + i);
            const isoDate = d.toISOString().split('T')[0];

            if (i === 0) this.selectedDate = isoDate; 

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

    // Helper: Convierte milisegundos de Salesforce Time a minutos del día
    sfTimeToMins(sfTimeMs) {
        if (!sfTimeMs) return null;
        return Math.floor(sfTimeMs / 60000);
    }

    @wire(getMatrixData, { selectedDate: '$selectedDate' })
    wiredMatrixData({ error, data }) {
        if (data) {
            let colorIndex = 0;
            this.activeEmployees = data.employees.map(emp => {
                const color = this.employeeColors[colorIndex % this.employeeColors.length];
                colorIndex++;
                return { id: emp.Id, name: emp.Name, color: color };
            });

            this.activeAppointments = data.appointments.map(appt => {
                const dt = new Date(appt.Start_Date_Time__c);
                const durationMins = appt.Service__r?.Duration_Minutes__c || 30;
                const endDt = new Date(dt.getTime() + durationMins * 60000);
                
                const startTimeStr = dt.toLocaleTimeString('es-UY', { hour: '2-digit', minute: '2-digit', hour12: false });
                const endTimeStr = endDt.toLocaleTimeString('es-UY', { hour: '2-digit', minute: '2-digit', hour12: false });
                
                const firstName = appt.Customer__r?.First_Name__c || '';
                const lastName = appt.Customer__r?.Last_Name__c || '';
                const rawPrice = appt.Service__r?.Price__c;
                
                return {
                    id: appt.Id,
                    employeeId: appt.Employee__c,
                    startTime: startTimeStr,
                    duration: durationMins,
                    customer: `${firstName} ${lastName}`.trim() || 'Sin Nombre',
                    service: appt.Service__r?.Name || 'Servicio',
                    timeRange: `${startTimeStr} - ${endTimeStr}`,
                    priceText: rawPrice ? `$${rawPrice}` : 'Sin costo'
                };
            });

            // NUEVO: Procesar Horarios Base
            this.activeWorkingHours = data.workingHours.map(wh => {
                return {
                    employeeId: wh.Employee__c,
                    startMins: this.sfTimeToMins(wh.Start_Hour__c),
                    endMins: this.sfTimeToMins(wh.End_Hour__c),
                    startBreakMins: this.sfTimeToMins(wh.Start_Default_Break_Hour__c),
                    endBreakMins: this.sfTimeToMins(wh.End_Default_Break_Hour__c)
                };
            });

            // NUEVO: Procesar Ausencias
            const selectedDateObj = new Date(this.selectedDate + 'T00:00:00');
            this.activeAbsences = data.absences.map(abs => {
                const startDt = new Date(abs.Start_Date_Time__c);
                const endDt = new Date(abs.End_Date_Time__c);
                
                // Si la ausencia empezó días atrás, bloquea desde el minuto 0 de hoy.
                let startMins = 0;
                if (startDt.getDate() === selectedDateObj.getDate() && startDt.getMonth() === selectedDateObj.getMonth()) {
                    startMins = (startDt.getHours() * 60) + startDt.getMinutes();
                }

                // Si la ausencia termina en días futuros, bloquea hasta el final del día (1440 mins).
                let endMins = 1440;
                if (endDt.getDate() === selectedDateObj.getDate() && endDt.getMonth() === selectedDateObj.getMonth()) {
                    endMins = (endDt.getHours() * 60) + endDt.getMinutes();
                }

                return {
                    employeeId: abs.Employee__c,
                    startMins: startMins,
                    endMins: endMins,
                    category: abs.Category__c || 'Ausente'
                };
            });

            // Llenamos las opciones de las clientas (esto sigue siendo global)
            this.customerOptions = data.allCustomers.map(c => ({ label: c.Name, value: c.Id }));
            
            // NUEVO: Guardamos los servicios y la tabla de unión cruda en memoria
            this.rawAllServices = data.allServices;
            this.rawEmployeeServices = data.employeeServices;

            this.generateMatrix();
        } else if (error) {
            console.error('Error al recuperar información:', error);
        }
    }

    handleDateSelect(event) {
        const selected = event.currentTarget.dataset.date;
        this.selectedDate = selected;
        this.weekDays = this.weekDays.map(day => ({
            ...day,
            cssClass: day.dateKey === selected ? 'date-card date-card--active' : 'date-card'
        }));
    }

    timeToMins(timeStr) {
        const [hours, minutes] = timeStr.split(':').map(Number);
        return (hours * 60) + minutes;
    }

    generateMatrix() {
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
                
                // 1. Verificar Citas
                const activeAppt = this.activeAppointments.find(appt => {
                    if (appt.employeeId !== emp.id) return false;
                    const apptStartMins = this.timeToMins(appt.startTime);
                    const apptEndMins = apptStartMins + appt.duration;
                    return slotMins >= apptStartMins && slotMins < apptEndMins;
                });

                if (activeAppt) {
                    const isStart = this.timeToMins(activeAppt.startTime) === slotMins;
                    const isEnd = (this.timeToMins(activeAppt.startTime) + activeAppt.duration - 30) === slotMins; 
                    
                    let cardClass = 'cell-appt';
                    if (isStart && isEnd) cardClass += ' cell-appt-single'; 
                    else if (isStart) cardClass += ' cell-appt-start'; 
                    else if (isEnd) cardClass += ' cell-appt-end'; 
                    else cardClass += ' cell-appt-body'; 

                    cells.push({
                        id: `${emp.id}_${timeLabel}`,
                        isTimeLabel: false,
                        isOccupied: true,
                        isStartBlock: isStart,
                        data: isStart ? activeAppt : null,
                        style: `background-color: ${emp.color};`,
                        cssClass: cardClass, 
                        tdStyle: isEnd ? '' : 'border-bottom: none !important;'
                    });
                    return; // Si hay cita, dejamos de evaluar (tiene prioridad en la UI)
                }

                // 2. Verificar Ausencias y Horarios Base
                let isBlocked = false;
                let isOutsideHours = false;
                let blockLabel = '';
                let hasOverrideBreak = false;

                // Evaluamos Ausencias creadas manualmente
                const activeAbs = this.activeAbsences.find(abs => abs.employeeId === emp.id && slotMins >= abs.startMins && slotMins < abs.endMins);
                
                if (activeAbs) {
                    isBlocked = true;
                    //blockLabel = activeAbs.category === 'Break' ? 'Descanso' : activeAbs.category;
                    blockLabel = 'No disponible';
                    if (activeAbs.category === 'Break') hasOverrideBreak = true;
                }

                // Evaluamos el Horario Base (Working Hours)
                const wh = this.activeWorkingHours.find(w => w.employeeId === emp.id);
                if (!wh || slotMins < wh.startMins || slotMins >= wh.endMins) {
                    isOutsideHours = true;
                } else if (!hasOverrideBreak && wh.startBreakMins && wh.endBreakMins) {
                    // Si NO hay un descanso manual sobreescrito, aplicamos el descanso por defecto
                    if (slotMins >= wh.startBreakMins && slotMins < wh.endBreakMins) {
                        isBlocked = true;
                        blockLabel = 'No disponible';
                    }
                }

                if (isOutsideHours) {
                    cells.push({
                        id: `${emp.id}_${timeLabel}`,
                        isTimeLabel: false,
                        isOccupied: false,
                        isBlocked: true,
                        cssClass: 'cell-outside-hours' // Gris sólido oscuro
                    });
                } else if (isBlocked) {
                    cells.push({
                        id: `${emp.id}_${timeLabel}`,
                        isTimeLabel: false,
                        isOccupied: false,
                        isBlocked: true,
                        blockLabel: blockLabel,
                        cssClass: 'cell-blocked-absence' // Patrón de rayas
                    });
                } else {
                    cells.push({
                        id: `${emp.id}_${timeLabel}`,
                        isTimeLabel: false,
                        isOccupied: false,
                        time: timeLabel,
                        empId: emp.id,
                        cssClass: 'cell-free free-cell'
                    });
                }
            });

            return { id: `ROW_${timeLabel}`, cells: cells };
        });
    }

    // --- ACCIÓN 1: CLICK EN ESPACIO LIBRE (ABRE MODAL DE CREACIÓN) ---
    handleEmptySlotClick(event) {
        this.formTimeLabel = event.currentTarget.dataset.time;
        this.formEmpId = event.currentTarget.dataset.empid;
        this.formEmpName = this.activeEmployees.find(e => e.id === this.formEmpId).name;
        
        // 1. Buscamos qué IDs de servicio tiene habilitados este empleado específico
        const allowedServiceIds = this.rawEmployeeServices
            .filter(es => es.Employee__c === this.formEmpId)
            .map(es => es.Service__c);

        // 2. Filtramos la lista global de servicios para mostrar solo los habilitados
        this.serviceOptions = this.rawAllServices
            .filter(service => allowedServiceIds.includes(service.Id))
            .map(s => ({ 
                label: `${s.Name} (${s.Duration_Minutes__c} min)`, 
                value: s.Id 
            }));

        // 3. Limpiamos las selecciones anteriores y abrimos el modal
        this.selectedCustomerId = '';
        this.selectedServiceId = '';
        this.isCreateModalOpen = true;
    }
}