import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getMatrixData from '@salesforce/apex/AA_SalonAppointmentsController.getMatrixData';
import createNewAppointment from '@salesforce/apex/AA_SalonAppointmentsController.createNewAppointment';
import confirmAppointment from '@salesforce/apex/AA_SalonAppointmentsController.confirmAppointment';
import getWeekHolidays from '@salesforce/apex/AA_SalonAppointmentsController.getWeekHolidays';
import completeAppointment from '@salesforce/apex/AA_SalonAppointmentsController.completeAppointment';
import cancelAppointment from '@salesforce/apex/AA_SalonAppointmentsController.cancelAppointment';
import reassignAppointment from '@salesforce/apex/AA_SalonAppointmentsController.reassignAppointment';
import markReminderAsSent from '@salesforce/apex/AA_SalonAppointmentsController.markReminderAsSent';
import createAbsence from '@salesforce/apex/AA_SalonAppointmentsController.createAbsence';
import deleteAbsence from '@salesforce/apex/AA_SalonAppointmentsController.deleteAbsence';
import setNoShowAppointment from '@salesforce/apex/AA_SalonAppointmentsController.setNoShowAppointment';

export default class AASalonMatrixAdmin extends LightningElement {
    
    @track weekDays = [];
    @track selectedDate = ''; 
    @track baseDate = new Date();
    @track gridHeaders = [];
    @track weekHolidays = [];
    @track selectedHolidayName = '';

    get baseDateString() {
        return this.baseDate.toISOString().split('T')[0];
    }
    @track gridRows = [];

    @track isAbsenceModalOpen = false;
    @track selectedBlock = {};

    @track activeEmployees = [];
    @track activeAppointments = [];
    @track activeAbsences = []; 
    @track activeWorkingHours = []; 

    // Opciones para los comboboxes del formulario
    @track customerOptions = [];
    @track serviceOptions = [];

    // Datos crudos para selectores
    rawAllServices = [];
    rawAllCustomers = [];
    rawEmployeeServices = [];

    // Modales y formularios y variables de control ---
    @track isCreateModalOpen = false;
    @track isDetailModalOpen = false;
    @track isAbsenceModalOpen = false;
    @track eligibleEmployeesOptions = [];
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
    @track isNoShowing = false;

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
        this.weekDays = [];
        for (let i = 0; i < 7; i++) {
            const current = new Date(this.baseDate);
            current.setDate(this.baseDate.getDate() + i);
            
            const dStr = current.getFullYear() + '-' + 
                         String(current.getMonth() + 1).padStart(2, '0') + '-' + 
                         String(current.getDate()).padStart(2, '0');

            if (i === 0 && !this.selectedDate) this.selectedDate = dStr;

            const holiday = this.weekHolidays.find(h => h.Date__c === dStr);

            let css = 'date-card';
            if (holiday) css += ' date-card--holiday';
            if (dStr === this.selectedDate) css += ' date-card--active';

            this.weekDays.push({
                dateKey: dStr,
                dayOfWeek: current.toLocaleDateString('es-UY', { weekday: 'short' }),
                dayNumber: current.getDate(),
                month: current.toLocaleDateString('es-UY', { month: 'short' }),
                cssClass: css,
                isHoliday: !!holiday
            });
        }
    }

    sfTimeToMins(sfTimeMs) {
        if (!sfTimeMs) return null;
        return Math.floor(sfTimeMs / 60000);
    }

    @wire(getWeekHolidays, { baseDate: '$baseDateString' })
    wiredHolidays({ error, data }) {
        if (data) {
            this.weekHolidays = data;
            this.initWeekDays();
            if (this.rawAllServices) {
                this.generateMatrix();
            }
        } else if (error) {
            console.error('Error fetching holidays', error);
        }
    }

    @wire(getMatrixData, { selectedDate: '$selectedDate' })
    wiredMatrixData(result) {
        this.wiredMatrixResult = result; 
        const { error, data } = result;
        
        if (data) {
            this.activeEmployees = data.employees.map(emp => {
                // Toma el color de Salesforce, o asigna uno aleatorio de la paleta si está vacío
                const color = emp.Color__c ? emp.Color__c : this.employeeColors[Math.floor(Math.random() * this.employeeColors.length)];
                return { id: emp.Id, name: ((emp.First_Name__c ? emp.First_Name__c + ' ' : '') + (emp.Last_Name__c ? emp.Last_Name__c : '')).trim() || emp.Name, color: color };
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
                    name: appt.Name, 
                    employeeId: appt.Employee__c,
                    serviceId: appt.Service__c,
                    startTime: startTimeStr,
                    duration: durationMins,
                    customer: `${firstName} ${lastName}`.trim() || 'Sin Nombre',
                    phone: appt.Customer__r?.Phone_Number__c || '', 
                    service: appt.Service__r?.Display_Name__c ? appt.Service__r.Display_Name__c : (appt.Service__r?.Name || 'Servicio'),
                    timeRange: `${startTimeStr} - ${endTimeStr}`,
                    priceText: rawPrice ? `$${rawPrice}` : 'Sin costo',
                    status: appt.Status__c,
                    isPending: appt.Status__c === 'Pending',
                    isConfirmed: appt.Status__c === 'Confirmed' || appt.Is_Customer_Confirmed__c,
                    isDone: appt.Status__c === 'Done',
                    isReminderSent: appt.Is_Reminder_Sent__c || !!appt.Reminder_Sent_Date__c,
                    internalComments: appt.Internal_Comments__c || '',
                    customerComments: appt.Customer__r?.Comments_From_Customer__c || '',
                    hasAllergies: appt.Customer__r?.Has_Allergies__c || false,
                    isPast: dt < new Date()
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
                    id: abs.Id,
                    employeeId: abs.Employee__c,
                    startMins: startMins,
                    endMins: endMins,
                    category: abs.Category__c || 'Break'
                };
            });

            this.customerOptions = data.allCustomers.map(c => ({ label: c.Name, value: c.Id }));
            
            if (data.branchWorkingHour) {
                const bwh = data.branchWorkingHour;
                const effOpen = bwh.Admin_Open_Time__c ? bwh.Admin_Open_Time__c : bwh.Open_Time__c;
                const effClose = bwh.Admin_Close_Time__c ? bwh.Admin_Close_Time__c : bwh.Close_Time__c;
                this.branchStartMins = this.sfTimeToMins(effOpen);
                this.branchEndMins = this.sfTimeToMins(effClose);
            } else {
                this.branchStartMins = 9 * 60;
                this.branchEndMins = 18 * 60;
            }
            this.rawAllServices = data.allServices;
            this.rawAllCustomers = data.allCustomers;
            this.rawEmployeeServices = data.employeeServices;

            this.generateMatrix();
        } else if (error) {
            console.error('Error al recuperar información:', error);
        }
    }

    handlePrevWeek() {
        this.baseDate.setDate(this.baseDate.getDate() - 7);
        this.baseDate = new Date(this.baseDate);
        this.initWeekDays();
    }

    handleNextWeek() {
        this.baseDate.setDate(this.baseDate.getDate() + 7);
        this.baseDate = new Date(this.baseDate);
        this.initWeekDays();
    }

    handleDatePicker(event) {
        if (event.target.value) {
            const [year, month, day] = event.target.value.split('-');
            this.baseDate = new Date(year, month - 1, day, 12, 0, 0);
            this.initWeekDays();
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
            ...this.activeEmployees.map(emp => {
                const empAppts = this.activeAppointments.filter(a => a.employeeId === emp.id);
                const count = empAppts.length;
                const totalMins = empAppts.reduce((acc, a) => acc + a.duration, 0);
                
                return {
                    id: emp.id,
                    label: emp.name,
                    statsLabel: `(${count} citas, ${totalMins} min)`,
                    isTime: false,
                    dotStyle: `background-color: ${emp.color};`,
                    cssClass: 'th-emp'
                };
            })
        ];

        const timeSlots = [];
        const startMins = this.branchStartMins || (9 * 60);
        const endMins = this.branchEndMins || (18 * 60);

        for (let mins = startMins; mins <= endMins; mins += 30) {
            const h = Math.floor(mins / 60);
            const m = mins % 60;
            const hourStr = String(h).padStart(2, '0');
            const minStr = String(m).padStart(2, '0');
            timeSlots.push(`${hourStr}:${minStr}`);
        }

        const currentHoliday = this.weekHolidays.find(h => h.Date__c === this.selectedDate);
        const isHoliday = !!currentHoliday;
        this.selectedHolidayName = currentHoliday ? currentHoliday.Name : '';

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

                    if (activeAppt.isDone) {
                        cardClass += ' cell-appt-done';
                    }

                    cells.push({
                        id: `${emp.id}_${timeLabel}`,
                        isTimeLabel: false,
                        isOccupied: true,
                        isStartBlock: isStart,
                        data: activeAppt, 
                        style: `background-color: ${emp.color}; cursor: pointer;`, 
                        cssClass: cardClass, 
                        tdStyle: isEnd ? '' : 'border-bottom: none !important;'
                    });
                    return;
                }

                if (isHoliday) {
                    cells.push({
                        id: `${emp.id}_${timeLabel}`, isTimeLabel: false, isOccupied: false, isBlocked: true,
                        blockType: 'Holiday',
                        time: timeLabel, empId: emp.id, cssClass: 'cell-holiday', blockCursor: 'cursor: not-allowed;'
                    });
                    return;
                }

                const hasDailyBreakOverride = this.activeAbsences.some(abs => abs.employeeId === emp.id && abs.category === 'Break');

                let isBlocked = false;
                let isOutsideHours = false;
                let blockLabel = '';
                let blockType = '';
                let absenceId = null;
                
                const activeAbs = this.activeAbsences.find(abs => abs.employeeId === emp.id && slotMins >= abs.startMins && slotMins < abs.endMins);
                
                if (activeAbs) {
                    isBlocked = true;
                    blockType = 'Break';
                    blockLabel = 'No disponible';
                    absenceId = activeAbs.id;
                }

                const wh = this.activeWorkingHours.find(w => w.employeeId === emp.id);
                if (!wh || slotMins < wh.startMins || slotMins >= wh.endMins) {
                    isOutsideHours = true;
                } else if (!isBlocked && !hasDailyBreakOverride && wh.startBreakMins && wh.endBreakMins) {
                    if (slotMins >= wh.startBreakMins && slotMins < wh.endBreakMins) {
                        isBlocked = true;
                        blockLabel = 'No disponible';
                        blockType = 'DefaultBreak';
                    }
                }

                if (isOutsideHours) {
                   cells.push({
                        id: `${emp.id}_${timeLabel}`, isTimeLabel: false, isOccupied: false, isBlocked: false,
                        time: timeLabel, empId: emp.id,
                        cssClass: 'cell-outside-hours free-cell',
                        outsideLabel: ''
                    });
                } else if (isBlocked) {
                   cells.push({
                        id: `${emp.id}_${timeLabel}`, isTimeLabel: false, isOccupied: false, isBlocked: true,
                        blockLabel: blockLabel, blockType: blockType, absenceId: absenceId,
                        time: timeLabel, empId: emp.id, cssClass: 'cell-blocked-absence', blockCursor: 'cursor: pointer;'
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
                label: `${s.Display_Name__c ? s.Display_Name__c : s.Name} (${s.Duration_Minutes__c} min)`, 
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
                isDone: appt.isDone,
                isPending: appt.isPending,
                isPast: appt.isPast,
                hasAllergies: appt.hasAllergies,
                customerComments: appt.customerComments
            };

            // Calcular opciones de reasignación
            if (!appt.isDone) {
                const options = [];
                this.activeEmployees.forEach(employee => {
                    // Verificar si el empleado ofrece el servicio
                    const offersService = this.rawEmployeeServices.some(es => 
                        es.Employee__c === employee.id && es.Service__c === appt.serviceId
                    );
                    
                    if (offersService) {
                        // Verificar si el empleado está disponible (o es el asignado actualmente)
                        const isAvailable = employee.id === appt.employeeId || 
                            this.isEmployeeAvailable(employee.id, appt.startTime, appt.duration, appt.id);
                        
                        if (isAvailable) {
                            options.push({ label: employee.name, value: employee.id });
                        }
                    }
                });
                this.eligibleEmployeesOptions = options;
            } else {
                this.eligibleEmployeesOptions = [];
            }

            this.tempInternalComments = appt.internalComments || '';
            this.isDetailModalOpen = true;
        }
    }

    handleReassignChange(event) {
        const newEmployeeId = event.detail.value;
        if (newEmployeeId === this.selectedAppt.employeeId) return;

        this.isSaving = true;
        reassignAppointment({ appointmentId: this.selectedAppt.id, newEmployeeId: newEmployeeId })
            .then(() => this.closeAndRefresh())
            .catch(error => {
                console.error('Error reasignando cita:', error);
                this.isSaving = false;
            });
    }

    handleConfirmAction() {
        this.isConfirming = true;
        confirmAppointment({ appointmentId: this.selectedAppt.id, internalComments: this.tempInternalComments })
            .then(() => this.closeAndRefresh())
            .catch(err => { console.error(err); this.isConfirming = false; });
    }

    handleCommentChange(event) {
        this.tempInternalComments = event.target.value;
    }

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

    handleNoShowAction() {
        this.isNoShowing = true;
        setNoShowAppointment({ appointmentId: this.selectedAppt.id })
            .then(() => this.closeAndRefresh())
            .catch(err => { console.error(err); this.isNoShowing = false; });
    }

    handleFormChange(event) {
        const field = event.target.name;
        if (field === 'customer') this.selectedCustomerId = event.target.value;
        if (field === 'service') this.selectedServiceId = event.target.value;
        if (field === 'absenceCategory') this.selectedAbsenceCategory = event.target.value;
        if (field === 'absenceDuration') this.selectedAbsenceDuration = event.target.value;
    }

    handleSaveAction() {
        this.isSaving = true;

        const [hours, minutes] = this.formTimeLabel.split(':').map(Number);
        const startDateTime = new Date(this.selectedDate + 'T00:00:00');
        startDateTime.setHours(hours, minutes, 0, 0);

        if (this.isAppointmentTabActive) {
            if (!this.selectedCustomerId || !this.selectedServiceId) { this.isSaving = false; return; }
            
            createNewAppointment({ customerId: this.selectedCustomerId, employeeId: this.formEmpId, serviceId: this.selectedServiceId, startDateTime: startDateTime })
                .then(() => this.closeAndRefresh())
                .catch(err => { console.error(err); this.isSaving = false; });
        } else {
            if (!this.selectedAbsenceCategory || !this.selectedAbsenceDuration) { this.isSaving = false; return; }
            
            createAbsence({ employeeId: this.formEmpId, startDateTime: startDateTime, durationMinutes: parseInt(this.selectedAbsenceDuration, 10), category: this.selectedAbsenceCategory })
                .then(() => this.closeAndRefresh())
                .catch(err => { console.error(err); this.isSaving = false; });
        }
    }

    closeModals() {
        this.isCreateModalOpen = false;
        this.isDetailModalOpen = false;
        this.isSaving = false; 
        this.isConfirming = false; 
        this.isCompleting = false; 
        this.isCancelling = false;
        this.isNoShowing = false;
        this.isAbsenceModalOpen = false;
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
        if (field === 'service') this.selectedServiceId = event.target.value;
        if (field === 'absenceCategory') this.selectedAbsenceCategory = event.target.value;
        if (field === 'absenceDuration') this.selectedAbsenceDuration = event.target.value;
    }

    handleCustomerSelect(event) {
        this.selectedCustomerId = event.detail.customerId;
        // Optionally save the customerName if needed
    }

// --- ACCIÓN: CLICK EN SLOT BLOQUEADO ---
    isEmployeeAvailable(empId, startTimeStr, durationMins, excludeApptId) {
        const startMins = this.timeToMins(startTimeStr);
        const endMins = startMins + durationMins;

        // 1. Check working hours
        const wh = this.activeWorkingHours.find(w => w.employeeId === empId);
        if (!wh || startMins < wh.startMins || endMins > wh.endMins) return false;

        // 2. Check breaks
        const hasDailyBreakOverride = this.activeAbsences.some(abs => abs.employeeId === empId && abs.category === 'Break');
        if (!hasDailyBreakOverride && wh.startBreakMins && wh.endBreakMins) {
            if (startMins < wh.endBreakMins && endMins > wh.startBreakMins) return false;
        }

        // 3. Check absences
        const overlapsAbsence = this.activeAbsences.some(abs => {
            if (abs.employeeId !== empId) return false;
            return startMins < abs.endMins && endMins > abs.startMins;
        });
        if (overlapsAbsence) return false;

        // 4. Check other appointments
        const overlapsAppt = this.activeAppointments.some(appt => {
            if (appt.employeeId !== empId || appt.id === excludeApptId) return false;
            const apptStart = this.timeToMins(appt.startTime);
            const apptEnd = apptStart + appt.duration;
            return startMins < apptEnd && endMins > apptStart;
        });
        if (overlapsAppt) return false;

        return true;
    }

    handleBlockedClick(event) {
        const type = event.currentTarget.dataset.type;
        console.info('handleBlockedClick: '+type);
        if (!type) return; // Si es un click fuera de hora, se ignora

        this.selectedBlock = {
            type: type,
            absenceId: event.currentTarget.dataset.absid,
            time: event.currentTarget.dataset.time,
            empId: event.currentTarget.dataset.empid,
            empName: this.activeEmployees.find(e => e.id === event.currentTarget.dataset.empid).name
        };
        this.isAbsenceModalOpen = true;
    }

    // --- ACCIÓN: LIBERAR HORARIO ---
    handleFreeSlot() {
        this.isSaving = true;

        console.info('deleteAbsence: '+this.selectedBlock.type);

        if (this.selectedBlock.type === 'DefaultBreak') {
            // Crea un Break fantasma de 0 minutos para anular el descanso por defecto del día
            const startDateTime = new Date(this.selectedDate + 'T00:00:00');
            createAbsence({ employeeId: this.selectedBlock.empId, startDateTime: startDateTime, durationMinutes: 0, category: 'Break' })
                .then(() => this.closeAndRefresh())
                .catch(err => { console.error(err); this.isSaving = false; });
        } else if (this.selectedBlock.type === 'Break') {
            console.info('deleteAbsence: '+this.selectedBlock.absenceId);
            // Elimina el bloqueo manual existente
            deleteAbsence({ absenceId: this.selectedBlock.absenceId })
                .then(() => this.closeAndRefresh())
                .catch(err => { console.error(err); this.isSaving = false; });
        }
    }

}