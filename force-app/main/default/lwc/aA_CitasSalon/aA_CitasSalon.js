import { LightningElement, track, wire } from 'lwc';
import getSalonAppointments from '@salesforce/apex/AA_SalonAppointmentsController.getSalonAppointments';

export default class AA_CitasSalon extends LightningElement {
    @track allAppointments = [];
    @track isLoading = true;
    @track isAdmin = false;

    // Filtros activos
    @track selectedEmployeeId = 'ALL';
    @track selectedTab = 'HOY'; // HOY, PROXIMOS, CANCELADOS

    // Paleta de colores para los empleados (como en tu mock original)
    employeeColors = ['#B23A3A', '#D4A017', '#3A70A1', '#5A8A4F', '#6B4F8E'];

    @wire(getSalonAppointments)
    wiredAppointments({ error, data }) {
        if (data) {
            console.info(JSON.stringify(data, null, 2));
            if (!data.appointments) {
                console.warn('Estructura de datos inesperada (posible caché). Forzando recarga...');
                return; 
            }
            this.isAdmin = data.isAdmin;
            this.allAppointments = data.appointments.map(appt => {
                const dt = new Date(appt.Start_Date_Time__c);
                
                // Formateo de fechas y horas
                const DOW = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
                const MESES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Setiembre', 'Octubre', 'Noviembre', 'Diciembre'];
                
                const fechaHeader = `${DOW[dt.getDay()]} ${dt.getDate()} De ${MESES[dt.getMonth()]}`;
                const horaStr = dt.toLocaleTimeString('es-UY', { hour: '2-digit', minute: '2-digit' });
                
                const firstName = appt.Customer__r?.First_Name__c || '';
                const lastName = appt.Customer__r?.Last_Name__c || '';
                
                return {
                    ...appt,
                    fechaRaw: dt,
                    fechaHeader: fechaHeader,
                    horaStr: horaStr,
                    customerName: `${firstName} ${lastName}`.trim() || 'Sin Nombre',
                    phone: appt.Customer__r?.Phone_Number__c || 'Sin teléfono',
                    serviceName: appt.Service__r?.Name || 'Servicio',
                    duration: appt.Service__r?.Duration_Minutes__c || 30,
                    employeeName: appt.Employee__r?.Name || 'Equipo',
                    employeeId: appt.Employee__c,
                    isCancelled: appt.Status__c === 'Cancelled'
                };
            });
            this.isLoading = false;
        } else if (error) {
            console.error('Error cargando citas:', JSON.stringify(error));
            this.isLoading = false;
        }
    }

    // 1. GENERAR FILTRO DE EMPLEADOS (PILLS)
    get employeePills() {
        const pills = [];
        const seen = new Set();
        let colorIndex = 0;

        // Botón "Todo el equipo"
        pills.push({
            id: 'ALL',
            label: 'Todo el equipo',
            isAll: true,
            cssClass: this.selectedEmployeeId === 'ALL' ? 'prof-pill prof-pill--active' : 'prof-pill'
        });

        // Botones dinámicos por empleado
        this.allAppointments.forEach(appt => {
            if (appt.employeeId && !seen.has(appt.employeeId)) {
                seen.add(appt.employeeId);
                const color = this.employeeColors[colorIndex % this.employeeColors.length];
                colorIndex++;
                
                pills.push({
                    id: appt.employeeId,
                    label: appt.employeeName,
                    color: color,
                    isAll: false,
                    style: `background-color: ${color};`,
                    cssClass: this.selectedEmployeeId === appt.employeeId ? 'prof-pill prof-pill--active' : 'prof-pill'
                });
            }
        });
        return pills;
    }

    // 2. GENERAR PESTAÑAS (TABS)
    get tabs() {
        return [
            { id: 'HOY', label: 'Hoy', cssClass: this.selectedTab === 'HOY' ? 'admin-tab admin-tab--active' : 'admin-tab' },
            { id: 'PROXIMOS', label: 'Próximos', cssClass: this.selectedTab === 'PROXIMOS' ? 'admin-tab admin-tab--active' : 'admin-tab' },
            { id: 'CANCELADOS', label: 'Cancelados', cssClass: this.selectedTab === 'CANCELADOS' ? 'admin-tab admin-tab--active' : 'admin-tab' }
        ];
    }

    // 3. FILTRAR Y AGRUPAR CITAS PARA LA VISTA
    get groupedAppointments() {
        if (!this.allAppointments || this.allAppointments.length === 0) return [];

        const hoy = new Date();
        hoy.setHours(0, 0, 0, 0); // Inicio del día de hoy

        // A. Filtrar por Empleado, Pestaña y Estado
        const filtered = this.allAppointments.filter(appt => {
            // Filtro de empleado
            if (this.selectedEmployeeId !== 'ALL' && appt.employeeId !== this.selectedEmployeeId) return false;

            // Filtro de Pestaña/Fecha
            const apptDate = new Date(appt.fechaRaw);
            apptDate.setHours(0, 0, 0, 0);

            if (this.selectedTab === 'CANCELADOS') {
                return appt.isCancelled;
            } else if (this.selectedTab === 'HOY') {
                return !appt.isCancelled && apptDate.getTime() === hoy.getTime();
            } else if (this.selectedTab === 'PROXIMOS') {
                return !appt.isCancelled && apptDate.getTime() > hoy.getTime();
            }
            return false;
        });

        if (filtered.length === 0) return [];

        // B. Agrupar por Fecha (para el encabezado "Sáb 23 De Mayo")
        const groups = {};
        filtered.forEach(appt => {
            if (!groups[appt.fechaHeader]) {
                groups[appt.fechaHeader] = [];
            }
            // Agregamos estilos a la tarjeta
            const statusLabel = appt.isCancelled ? 'CANCELADO' : (appt.Status__c === 'Pending' ? 'PENDIENTE' : 'CONFIRMADO');
            const statusClass = appt.isCancelled ? 'status-label status-label--cancelled' : 'status-label status-label--pending';
            // Buscamos el color del empleado asignado arriba
            const empPill = this.employeePills.find(p => p.id === appt.employeeId);
            const borderColor = empPill && empPill.color ? empPill.color : '#333';

            groups[appt.fechaHeader].push({
                ...appt,
                statusLabel: statusLabel,
                statusClass: statusClass,
                cardStyle: `border-left: 4px solid ${borderColor};`
            });
        });

        // Convertir el objeto a Array para el iterador HTML
        return Object.keys(groups).map(dateStr => {
            return {
                dateHeader: dateStr,
                appointments: groups[dateStr]
            };
        });
    }

    get hasData() {
        return this.groupedAppointments.length > 0;
    }

    // EVENTOS DE LA UI
    handleEmployeeSelect(event) {
        this.selectedEmployeeId = event.currentTarget.dataset.id;
    }

    handleTabSelect(event) {
        this.selectedTab = event.currentTarget.dataset.id;
    }  
}