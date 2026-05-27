import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getMatrixData from '@salesforce/apex/AA_SalonAppointmentsController.getMatrixData';
import createNewAppointment from '@salesforce/apex/AA_SalonAppointmentsController.createNewAppointment';
import confirmAppointment from '@salesforce/apex/AA_SalonAppointmentsController.confirmAppointment';
import completeAppointment from '@salesforce/apex/AA_SalonAppointmentsController.completeAppointment';
import cancelAppointment from '@salesforce/apex/AA_SalonAppointmentsController.cancelAppointment';
import markReminderAsSent from '@salesforce/apex/AA_SalonAppointmentsController.markReminderAsSent';
import createAbsence from '@salesforce/apex/AA_SalonAppointmentsController.createAbsence';

export default class AASalonMatrixAdmin extends LightningElement {
    
    @track weekDays = [];
    @track selectedDate = ''; 
    @track gridHeaders = [];
    @track gridRows = [];

    @track activeEmployees = [];
    @track activeAppointments = [];
    @track activeAbsences = []; 
    @track activeWorkingHours = []; 

    // Opciones para los comboboxes del formulario
    @track customerOptions = [];
    @track serviceOptions = [];

    // Almacenamiento crudo para filtrado dinámico
    rawAllServices = [];
    rawEmployeeServices = [];

    // --- NUEVO: Modales y variables de control ---
    @track isCreateModalOpen = false;
    @track isDetailModalOpen = false;
    @track selectedAppt = {}; 

    // Datos temporales del formulario de creación
    selectedCustomerId = '';
    selectedServiceId = '';
    formTimeLabel = '';
    formEmpId = '';
    formEmpName = '';
    @track tempInternalComments = ''; // NUEVO: Rastrea el texto del textarea

    // Estados de carga de botones en modales
    @track isSaving = false;
    @track isConfirming = false;
    @track isCompleting = false;
    @track isCancelling = false;

    wiredMatrixResult; // Almacena el resultado crudo para refreshApex

    employeeColors = ['#B23A3A', '#D4A017', '#3A70A1', '#5A8A4F', '#6B4F8E', '#A15C3A'];

    // --- VARIABLES DEL MODAL UNIFICADO ---
    @track isAppointmentTabActive = true; // Controla la pestaña activa
    
    // Variables para el bloqueo de horario
    selectedAbsenceCategory = '';
    selectedAbsenceDuration = '';

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

    sfTimeToMins(sfTimeMs) {
        if (!sfTimeMs) return null;
        return Math.floor(sfTimeMs / 60000);
    }

    @wire(getMatrixData, { selectedDate: '$selectedDate' })
    wiredMatrixData(result) {
        this.wiredMatrixResult = result; // Guardamos la referencia para el refreshApex
        const { error, data } = result;
        
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
                    phone: appt.Customer__r?.Phone_Number__c || '', // NUEVO
                    service: appt.Service__r?.Name || 'Servicio',
                    timeRange: `${startTimeStr} - ${endTimeStr}`,
                    priceText: rawPrice ? `$${rawPrice}` : 'Sin costo',
                    status: appt.Status__c,
                    isPending: appt.Status__c === 'Pending',
                    isConfirmed: appt.Status__c === 'Confirmed',
                    isDone: appt.Status__c === 'Done',
                    isReminderSent: !!appt.Reminder_Sent_Date__c,
                    internalComments: appt.Internal_Comments__c || ''
                };
            });

            this.activeWorkingHours = data.workingHours.map(wh => {
                return {
                    employeeId: wh.Employee__c,
                    startMins: this.sfTimeToMins(wh.Start_Hour__c),
                    endMins: this.sfTimeToMins(wh.End_Hour__c),
                    startBreakMins: this.sfTimeToMins(wh.Start_Default_Break_Hour__c),
                    endBreakMins: this.sfTimeToMins(wh.End_Default_Break_Hour__c)
                };
            });

            const selectedDateObj = new Date(this.selectedDate + 'T00:00:00');
            this.activeAbsences = data.absences.map(abs => {
                const startDt = new Date(abs.Start_Date_Time__c);
                const endDt = new Date(abs.End_Date_Time__c);
                
                let startMins = 0;
                if (startDt.getDate() === selectedDateObj.getDate() && startDt.getMonth() === selectedDateObj.getMonth()) {
                    startMins = (startDt.getHours() * 60) + startDt.getMinutes();
                }

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

            this.customerOptions = data.allCustomers.map(c => ({ label: c.Name, value: c.Id }));
            
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

                    // ACTUALIZADO: Si la cita está terminada, le anexamos la clase de atenuación suave
                    if (activeAppt.isDone) {
                        cardClass += ' cell-appt-done';
                    }

                    cells.push({
                        id: `${emp.id}_${timeLabel}`,
                        isTimeLabel: false,
                        isOccupied: true,
                        isStartBlock: isStart,
                        // SOLUCIÓN: Pasamos la cita entera a todos los bloques, no solo al primero.
                        data: activeAppt, 
                        style: `background-color: ${emp.color}; cursor: pointer;`, // Agregamos cursor pointer para que se note que es clickeable
                        cssClass: cardClass, 
                        tdStyle: isEnd ? '' : 'border-bottom: none !important;'
                    });
                    return;
                }

                let isBlocked = false;
                let isOutsideHours = false;
                let blockLabel = '';
                let hasOverrideBreak = false;

                const activeAbs = this.activeAbsences.find(abs => abs.employeeId === emp.id && slotMins >= abs.startMins && slotMins < abs.endMins);
                
                if (activeAbs) {
                    isBlocked = true;
                    blockLabel = 'No disponible';
                    if (activeAbs.category === 'Break') hasOverrideBreak = true;
                }

                const wh = this.activeWorkingHours.find(w => w.employeeId === emp.id);
                if (!wh || slotMins < wh.startMins || slotMins >= wh.endMins) {
                    isOutsideHours = true;
                } else if (!hasOverrideBreak && wh.startBreakMins && wh.endBreakMins) {
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
                        cssClass: 'cell-outside-hours' 
                    });
                } else if (isBlocked) {
                    cells.push({
                        id: `${emp.id}_${timeLabel}`,
                        isTimeLabel: false,
                        isOccupied: false,
                        isBlocked: true,
                        blockLabel: blockLabel,
                        cssClass: 'cell-blocked-absence' 
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

    // --- ACCIÓN: CLICK EN ESPACIO LIBRE (CREACIÓN) ---
    handleEmptySlotClick(event) {
        this.formTimeLabel = event.currentTarget.dataset.time;
        this.formEmpId = event.currentTarget.dataset.empid;
        this.formEmpName = this.activeEmployees.find(e => e.id === this.formEmpId).name;
        this.isAppointmentTabActive = true;
        
        const allowedServiceIds = this.rawEmployeeServices
            .filter(es => es.Employee__c === this.formEmpId)
            .map(es => es.Service__c);

        this.serviceOptions = this.rawAllServices
            .filter(service => allowedServiceIds.includes(service.Id))
            .map(s => ({ 
                label: `${s.Name} (${s.Duration_Minutes__c} min)`, 
                value: s.Id 
            }));

        this.selectedCustomerId = '';
        this.selectedServiceId = '';
        this.isCreateModalOpen = true;
    }

   handleApptClick(event) {
        const apptId = event.currentTarget.dataset.id;
        const appt = this.activeAppointments.find(a => a.id === apptId);
        
        if (appt) {
            const emp = this.activeEmployees.find(e => e.id === appt.employeeId);
            this.selectedAppt = {
                ...appt,
                employeeName: emp ? emp.name : 'Equipo',
                waButtonLabel: appt.isReminderSent ? 'Reenviar' : 'Recordatorio',
                waButtonClass: appt.isReminderSent ? 'modal-btn modal-btn--sent' : 'modal-btn modal-btn--wa',
                waLink: this.generateWhatsAppLink(appt.phone, appt.customer, appt.service, appt.startTime),
                // ASEGÚRATE DE PASAR ESTAS BANDERAS:
                isDone: appt.isDone,
                isPending: appt.isPending
            };

            this.tempInternalComments = appt.internalComments || '';
            this.isDetailModalOpen = true;
        }
    }

    // --- NUEVO: MANEJADORES DE TRANSACCIONES (MODAL DETALLE) ---
    handleConfirmAction() {
        this.isConfirming = true;
        confirmAppointment({ appointmentId: this.selectedAppt.id, internalComments: this.tempInternalComments })
            .then(() => this.closeAndRefresh())
            .catch(err => { console.error(err); this.isConfirming = false; });
    }

    // NUEVO: Captura la escritura de la profesional
    handleCommentChange(event) {
        this.tempInternalComments = event.target.value;
    }

    // ACTUALIZADO: Envía los comentarios al marcar como realizado
    handleDoneAction() {
        this.isCompleting = true;
        completeAppointment({ appointmentId: this.selectedAppt.id, internalComments: this.tempInternalComments })
            .then(() => this.closeAndRefresh())
            .catch(err => { console.error(err); this.isCompleting = false; });
    }

    handleCancelAction() {
        this.isCancelling = true;
        cancelAppointment({ appointmentId: this.selectedAppt.id, internalComments: this.tempInternalComments })
            .then(() => this.closeAndRefresh())
            .catch(err => { console.error(err); this.isCancelling = false; });
    }

    handleWaAction() {
        markReminderAsSent({ appointmentId: this.selectedAppt.id })
            .then(() => refreshApex(this.wiredMatrixResult))
            .catch(err => console.error(err));
    }

    // --- NUEVO: GUARDAR NUEVA CITA (MODAL CREACIÓN) ---
    handleFormChange(event) {
        if (event.target.name === 'customer') this.selectedCustomerId = event.target.value;
        if (event.target.name === 'service') this.selectedServiceId = event.target.value;
    }

    handleSaveAction() {
        this.isSaving = true;

        const [hours, minutes] = this.formTimeLabel.split(':').map(Number);
        const startDateTime = new Date(this.selectedDate + 'T00:00:00');
        startDateTime.setHours(hours, minutes, 0, 0);

        if (this.isAppointmentTabActive) {
            // FLUJO: NUEVA CITA
            if (!this.selectedCustomerId || !this.selectedServiceId) { this.isSaving = false; return; }
            
            createNewAppointment({ customerId: this.selectedCustomerId, employeeId: this.formEmpId, serviceId: this.selectedServiceId, startDateTime: startDateTime })
                .then(() => this.closeAndRefresh())
                .catch(err => { console.error(err); this.isSaving = false; });
        } else {
            // FLUJO: BLOQUEO DE HORARIO
            if (!this.selectedAbsenceCategory || !this.selectedAbsenceDuration) { this.isSaving = false; return; }
            
            createAbsence({ employeeId: this.formEmpId, startDateTime: startDateTime, durationMinutes: parseInt(this.selectedAbsenceDuration, 10), category: this.selectedAbsenceCategory })
                .then(() => this.closeAndRefresh())
                .catch(err => { console.error(err); this.isSaving = false; });
        }
    }

    // --- NUEVO: FUNCIONES AUXILIARES DE MODALES ---
    closeModals() {
        this.isCreateModalOpen = false;
        this.isDetailModalOpen = false;
        this.isSaving = false; 
        this.isConfirming = false; 
        this.isCompleting = false; 
        this.isCancelling = false;
    }

    closeAndRefresh() {
        this.closeModals();
        return refreshApex(this.wiredMatrixResult);
    }

    generateWhatsAppLink(phone, name, service, time) {
        if (!phone) return null;
        const text = `Hola ${name}, te escribimos del salón para recordarte tu turno de ${service} mañana a las ${time} hs. ¿Nos confirmas tu asistencia?`;
        return `https://wa.me/${phone.replace(/\D/g, '')}?text=${encodeURIComponent(text)}`;
    }

    get absenceCategoryOptions() {
        return [
            { label: '☕ Descanso / Break', value: 'Break' },
            { label: '🍽️ Almuerzo', value: 'Lunch' },
            { label: '🎓 Reunión o Capacitación', value: 'Meeting' },
            { label: '⛔ Ausencia Personal', value: 'Personal' }
        ];
    }

    get absenceDurationOptions() {
        return [
            { label: '30 minutos', value: '30' },
            { label: '1 hora', value: '60' },
            { label: '1 hora y 30 minutos', value: '90' },
            { label: '2 horas', value: '120' }
        ];
    }

    get appointmentTabClass() { return this.isAppointmentTabActive ? 'modal-tab active' : 'modal-tab'; }
    get absenceTabClass() { return !this.isAppointmentTabActive ? 'modal-tab active' : 'modal-tab'; }

    handleTabClick(event) {
        this.isAppointmentTabActive = event.currentTarget.dataset.tab === 'appointment';
    }

    // ACTUALIZA tu handleFormChange actual para incluir los nuevos selects:
    handleFormChange(event) {
        const field = event.target.name;
        if (field === 'customer') this.selectedCustomerId = event.target.value;
        if (field === 'service') this.selectedServiceId = event.target.value;
        if (field === 'absenceCategory') this.selectedAbsenceCategory = event.target.value;
        if (field === 'absenceDuration') this.selectedAbsenceDuration = event.target.value;
    }


}