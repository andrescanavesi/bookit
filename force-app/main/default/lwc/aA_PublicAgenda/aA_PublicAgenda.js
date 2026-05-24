import { LightningElement, track, api } from 'lwc';

import getOrCreateCustomer from '@salesforce/apex/AA_PublicAgendaController.getOrCreateCustomer';
import getCategories from '@salesforce/apex/AA_PublicAgendaController.getCategories';
import getServices from '@salesforce/apex/AA_PublicAgendaController.getServices';
import updateCustomer from '@salesforce/apex/AA_PublicAgendaController.updateCustomer';
import getAvailableSlots from '@salesforce/apex/AA_PublicAgendaController.getAvailableSlots';
import saveAppointment from '@salesforce/apex/AA_PublicAgendaController.saveAppointment';
import getMisTurnos from '@salesforce/apex/AA_PublicAgendaController.getMisTurnos';
import cancelarAppointment from '@salesforce/apex/AA_PublicAgendaController.cancelarAppointment';

export default class AAPublicAgenda extends LightningElement {
    @api businessId

    // --- ESTADO GLOBAL ---
    currentScreen = 'welcome';
    reservaStep = 1;
    misTurnosStep = 1;

    @track categories = [];
    @track services = [];

      // --- ESTADO DE DISPONIBILIDAD ---
    @track diasDisponiblesList = [];
    @track horasDisponiblesList = [];
    @track isLoadingHours = false;
    @track isConfirming = false; // Nueva bandera para evitar doble clic


    @track persona = { id: '', firstName: '', lastName: '', celular: '099999999', email: 'a@a.com', indicaciones: '' };
   
   @track reserva = { 
        grupoSel: null, 
        servicioSel: null, 
        retiro: null, 
        fechaSel: null, 
        horaSel: null, 
        formaPago: null, 
        isNewCustomer: true,
        customerId: null 
    };

    @track misTurnosLogin = { celular: '099999999' };
    @track misTurnosEncontrados = []; // Array real para los resultados
    @track isLoadingTurnos = false;

    tieneIndicaciones = false;
    mostrarSubOpcionesRetiro = false;

    // --- ESTADO DEL EQUIPO (ADMIN) ---
    passwordIntento = '';
    errorLogin = '';
    adminFiltroProf = 'ALL';
    adminTab = 'proximos';

    // --- GETTERS: NAVEGACIÓN ---
    get isWelcome()     { return this.currentScreen === 'welcome'; }
    get isReserva()     { return this.currentScreen === 'reserva'; }
    get isMisTurnos()   { return this.currentScreen === 'misTurnos'; }
    get isPrecios()     { return this.currentScreen === 'precios'; }
    get isConsulta()    { return this.currentScreen === 'consulta'; }
    get isEquipoLogin() { return this.currentScreen === 'equipo_login'; }
    get isAdmin()       { return this.currentScreen === 'admin'; }

    // --- GETTERS: RESERVAS Y CLIENTES ---
    get isReservaPaso1() { return this.reservaStep === 1; }
    get isReservaPaso2() { return this.reservaStep === 2; }
    get isReservaPaso3() { return this.reservaStep === 3; }
    get isReservaPaso4() { return this.reservaStep === 4; }
    get isReservaPaso5() { return this.reservaStep === 5; }
    get isReservaPaso6() { return this.reservaStep === 6; } 
    get isReservaPaso7() { return this.reservaStep === 7; } 
    get isReservaPaso8() { return this.reservaStep === 8; } 

    get isMisTurnosPaso1() { return this.misTurnosStep === 1; }
    get isMisTurnosPaso2() { return this.misTurnosStep === 2; }

    get pillClaseNo() { return this.tieneIndicaciones ? 'pill' : 'pill pill--active'; }
    get pillClaseSi() { return this.tieneIndicaciones ? 'pill pill--active' : 'pill'; }

    get primerNombre() { 
        return this.persona.firstName || ''; 
    }

    get primerNombreMisTurnos() { return this.misTurnosLogin.nombre ? this.misTurnosLogin.nombre.split(' ')[0] : ''; }

    get isBotonConfirmarDeshabilitado() { 
        return !this.reserva.formaPago || this.isConfirming; 
    }

    get hasTurnos() {
        return this.misTurnosEncontrados && this.misTurnosEncontrados.length > 0;
    }
    get preciosAgrupados() {
        console.info('preciosAgrupados');
       return this.categories.map(cat => {
            const serviciosDelGrupo = this.services
                .filter(s => s.Grupo_Servicio__c === cat.id)
                .map(s => {
                    return {
                        ...s,
                        precioFormateado: s.Precio__c.toLocaleString('es-UY'),
                        tieneDescripcion: s.Descripcion_Extendida__c && s.Descripcion_Extendida__c.trim() !== ''
                    };
                });
            
            return { titulo: cat.label.toUpperCase(), servicios: serviciosDelGrupo };
        }).filter(g => g.servicios.length > 0);
    }

    // Reemplazamos el getter anterior por uno que use la variable del estado
    get categorias() {
        return this.categories;
    }
    
    get serviciosFiltrados() {
        console.info('serviciosFiltrados, grupo seleccionado '+this.reserva.grupoSel);
        //console.info(JSON.stringify( this.services, null, 2));
      if (!this.reserva.grupoSel) return [];
        
        const filteredServices = this.services
            .filter(s => s.Grupo_Servicio__c === this.reserva.grupoSel)
            .map(s => {
                let durText = s.Duracion_Base_Min__c >= 60 
                    ? `${Math.floor(s.Duracion_Base_Min__c / 60)} H${s.Duracion_Base_Min__c % 60 > 0 ? ` ${s.Duracion_Base_Min__c % 60} MIN` : ''}` 
                    : `${s.Duracion_Base_Min__c} MIN`;
                
                return { 
                    ...s, 
                    precioFormateado: s.Precio__c.toLocaleString('es-UY'),
                    duracionFormateada: durText, 
                    tieneDescripcion: s.Descripcion_Extendida__c && s.Descripcion_Extendida__c.trim() !== '' 
                };
            });

            //console.info(JSON.stringify( filteredServices, null, 2));
            return filteredServices;
    }

    get servicioSeleccionadoInfo() {
        //console.info('servicioSeleccionadoInfo...: '+this.reserva.servicioSel); 
        if (!this.reserva.servicioSel) return null;
        const service =  this.serviciosFiltrados.find(s => s.Id === this.reserva.servicioSel);
        //console.info('servicioSeleccionadoInfo: '+JSON.stringify(service, null, 2));
        return service
    }

    

    get isBotonFechaContinuarDeshabilitado() { return !this.reserva.horaSel; }

  get resumenDatos() {
        console.info('resumen datos');
        console.info(JSON.stringify(this.reserva, null, 2));
        if (!this.reserva.servicioSel || !this.reserva.fechaSel || !this.reserva.slotData) return {};
        
        const srv = this.services.find(s => s.Id === this.reserva.servicioSel);
        
        let totalCalculado = srv.Precio__c;
        if (this.reserva.retiro && this.reserva.retiro.material === 'blando') totalCalculado += 200;
        if (this.reserva.retiro && this.reserva.retiro.material === 'duro') totalCalculado += 300;
        
        // Extraemos los datos formateados directamente desde la respuesta de Apex
        const slot = this.reserva.slotData;

        return { 
            cliente: `${this.persona.firstName} ${this.persona.lastName}`.trim(),
            servicio: srv.Nombre_Visible__c, 
            profesional: slot.employeeName, // <-- Dinámico desde el backend
            fecha: `${slot.dayOfTheWeek} ${slot.dayNumber} de ${slot.monthName}`, // Ej: Miércoles 5 de Mayo
            hora: slot.hour24, 
            duracion: `${srv.Duracion_Base_Min__c} min`, 
            total: totalCalculado 
        };
    }

    get opcionesPago() {
        const opciones = ['Efectivo', 'Transferencia', 'Mercado Pago', 'Decido en el momento'];
        return opciones.map(op => ({ label: op, cssClass: this.reserva.formaPago === op ? 'pill pill--active' : 'pill' }));
    }

    get isBotonConfirmarDeshabilitado() { return !this.reserva.formaPago; }

    // --- GETTERS: ADMIN PANEL ---
    get adminPillsProfesionales() {
        return [
            { id: 'ALL', label: 'Todo el equipo', cssClass: this.adminFiltroProf === 'ALL' ? 'prof-pill prof-pill--active' : 'prof-pill' },
            { id: 'silvina', label: 'Silvina', color: '#3A70A1', cssClass: this.adminFiltroProf === 'silvina' ? 'prof-pill prof-pill--active' : 'prof-pill' },
            { id: 'sophie', label: 'Sophie', color: '#D4A017', cssClass: this.adminFiltroProf === 'sophie' ? 'prof-pill prof-pill--active' : 'prof-pill' },
            { id: 'dahiana', label: 'Dahiana', color: '#B23A3A', cssClass: this.adminFiltroProf === 'dahiana' ? 'prof-pill prof-pill--active' : 'prof-pill' },
            { id: 'yamila', label: 'Yamila', color: '#5A8A4F', cssClass: this.adminFiltroProf === 'yamila' ? 'prof-pill prof-pill--active' : 'prof-pill' }
        ];
    }

    get adminTabs() {
        return [
            { id: 'hoy', label: 'Hoy', cssClass: this.adminTab === 'hoy' ? 'admin-tab admin-tab--active' : 'admin-tab' },
            { id: 'proximos', label: 'Próximos', cssClass: this.adminTab === 'proximos' ? 'admin-tab admin-tab--active' : 'admin-tab' },
            { id: 'cancelados', label: 'Cancelados', cssClass: this.adminTab === 'cancelados' ? 'admin-tab admin-tab--active' : 'admin-tab' }
        ];
    }

    get adminAgendaData() {
        // Mock que replica la imagen proporcionada de "Próximos"
        return [
            { isHeader: true, label: 'Mar 5 De Mayo', key: 'h1' },
            { isBooking: true, id: 'b1', time: '09:00', status: 'CONFIRMADO', client: 'Juan', service: 'Manicuría sin esmalte · 30 min', phone: '099999999', prof: 'Soledad', profColor: '#6B4F8E', payment: 'Efectivo', borderStyle: 'border-left: 3px solid #6B4F8E;' },
            { isBooking: true, id: 'b2', time: '09:30', status: 'PENDIENTE', client: 'ddd', service: 'Estética de pies tradicional · 30 min', phone: '099776655', prof: 'Silvina', profColor: '#3A70A1', payment: 'Efectivo', borderStyle: 'border-left: 3px solid #3A70A1;' },
            { isGap: true, timeRange: '10:00 – 12:30', label: '150 MIN LIBRES', key: 'g1' }
        ];
    }

    // --- ACCIONES GENERALES ---

    connectedCallback() {

        // TODO this is for testing. Remove it for prod
        if(!this.businessId){
            this.businessId = 'a02gL00000Ix6AHQAZ';
        }
        if(this.businessId) {
            this.loadData();
        } else{
            console.error('no business selected');
        }
    }

    async loadData() {
        console.info('loading data for the business: '+this.businessId);
        try {
            // Cargamos categorías y servicios en paralelo para ganar velocidad
            const [categoriesDB, servicesDB] = await Promise.all([
                getCategories(),
                getServices()
            ]);

            console.info('categoriesDB: ');
            console.info(JSON.stringify(categoriesDB, null, 2));
            console.info('servicesDB: ');
            console.info(JSON.stringify(servicesDB, null, 2));

            // Mapeamos las categorías para mantener las clases CSS y la estructura
            this.categories = categoriesDB.map(cat => {
                // Lógica para detectar si es la tarjeta acentuada (Manos y Pies)
                const esCombinado = cat.Name.toLowerCase().includes('y'); 
                
                return {
                    id: cat.Id,
                    label: cat.Name,
                    sub: cat.Description_Short__c,
                    cssClass: esCombinado ? 'card card--accent between-rows' : 'card between-rows'
                };
            });

            // Mapeamos servicios (asegúrate de que Category__c ahora traiga el Id del Lookup)
            this.services = servicesDB.map(s => ({
                Id: s.Id,
                Nombre_Visible__c: s.Name,
                Duracion_Base_Min__c: s.Duration_Minutes__c,
                Precio__c: s.Price__c,
                Grupo_Servicio__c: s.AA_Service_Category__c, // Ahora es el ID de la categoría
                Descripcion_Extendida__c: s.Description__c || ''
            }));

        } catch (error) {
            console.error('Error cargando datos:' + JSON.stringify(error));
        }
    }

    handleInputChange(event) { this.persona[event.target.dataset.id] = event.target.value; }
    handleIndicacionesToggle(event) { this.tieneIndicaciones = (event.target.dataset.valor === 'si'); if (!this.tieneIndicaciones) this.persona.indicaciones = ''; }
    
    // avanzar paso 4 (service category selected, now the user has to select the service)
    handleSelectCategoria(event) { 
        console.info('handleSelectCategoria, avanzar paso 4: '+event.currentTarget.dataset.id);
        console.info(JSON.stringify(event.currentTarget.dataset, null, 2));
        this.reserva.grupoSel = event.currentTarget.dataset.id; 
        //this.serviciosFiltrados();
        this.reservaStep = 4; 
        }

    // Al seleccionar un servicio (Paso 4), guardamos su ID y decidimos a dónde ir (Retiro o Fecha)
    handleSelectServicio(event) { 
        console.info('handleSelectServicio: '+event.currentTarget.dataset.id);
        //console.info(JSON.stringify(event.currentTarget.dataset, null, 2));
        const srvId = event.currentTarget.dataset.id; 
        this.reserva.servicioSel = srvId;
        const srv = this.services.find(s => s.Id === srvId);
        console.info('handleSelectServicio, srv: '+JSON.stringify(srv, null, 2));
        if (srv && srv.Requiere_Pregunta_Retiro__c) { 
            console.info('handleSelectServicio, to step 5');
            this.reservaStep = 5; 
        } else { 
            console.info('handleSelectServicio, to step 6');
            //this.reservaStep = 6; 
             this.goToStep6(); 
        }
    }

   
    handleSelectRetiro(event) {
        const tipo = event.currentTarget.dataset.tipo; 
        this.reserva.retiro = { tipo: tipo };
        if (tipo === 'externo') { 
            this.mostrarSubOpcionesRetiro = true; 
        } else { 
            this.mostrarSubOpcionesRetiro = false; 
            this.goToStep6(); 
        }
    }

    handleSelectRetiroMaterial(event) { 
        this.reserva.retiro.material = event.target.dataset.material; 
        this.mostrarSubOpcionesRetiro = false; 
        this.goToStep6(); 
    }

    handleSelectFecha(event) { this.reserva.fechaSel = event.currentTarget.dataset.fecha; this.reserva.horaSel = null; }
    handleSelectHora(event) { this.reserva.horaSel = event.currentTarget.dataset.hora; }
    handleSelectPago(event) { this.reserva.formaPago = event.target.dataset.pago; }
    
    async handleConfirmarReserva() {
        this.isConfirming = true; // Deshabilita el botón
        
        try {
            // Tomamos los datos de nuestro estado local
            const params = {
                customerId: this.persona.id,
                employeeId: this.reserva.slotData.employeeId, // Viene del objeto AA_AvailableSlot
                serviceId: this.reserva.servicioSel,
                dayString: this.reserva.fechaSel, // Ej: '2026-05-21'
                hourString: this.reserva.horaSel  // Ej: '09:00'
            };

            console.info('Enviando datos de reserva a Salesforce:', JSON.stringify(params));

            // Llamada al backend
            const nuevaReserva = await saveAppointment(params);
            
            console.info('¡Reserva creada exitosamente!', nuevaReserva.Id);
            
            // Avanzamos a la pantalla de éxito (Paso 8)
            this.reservaStep = 8; 

        } catch (error) {
            console.error('Error al crear la reserva:', JSON.stringify(error));
            alert('Hubo un problema al procesar tu reserva. Por favor, intenta nuevamente.');
        } finally {
            this.isConfirming = false; // Rehabilitar botón por si falló y quiere reintentar
        }
    }
    
    handleMisTurnosInput(event) { this.misTurnosLogin[event.target.dataset.id] = event.target.value; }
   
    async handleBuscarTurnos() {
        if (!this.misTurnosLogin.celular) {
            alert('Por favor, ingresá tu celular para buscar tus turnos.');
            return;
        }

        this.isLoadingTurnos = true;

        try {
            const turnosDB = await getMisTurnos({ celular: this.misTurnosLogin.celular });

            const DOW = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
            const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'setiembre', 'octubre', 'noviembre', 'diciembre'];

            // Mapeamos los datos de Salesforce para la vista
            this.misTurnosEncontrados = turnosDB.map(t => {
                // Instanciamos la fecha. Si usas fechas UTC desde Apex, asegúrate de la zona horaria.
                const dt = new Date(t.Start_Date_Time__c);
                
                return {
                    Id: t.Id,
                    fechaStr: `${DOW[dt.getDay()]} ${dt.getDate()} de ${MESES[dt.getMonth()]}`,
                    // Formato HH:mm
                    horaStr: dt.toLocaleTimeString('es-UY', { hour: '2-digit', minute: '2-digit' }),
                    servicio: t.Service__r ? t.Service__r.Name : 'Servicio',
                    profesional: t.Employee__r ? t.Employee__r.Name : 'El equipo',
                    status: t.Status__c
                };
            });

            this.misTurnosStep = 2;

        } catch (error) {
            console.error('Error buscando mis turnos:', JSON.stringify(error));
            alert('Hubo un problema al buscar tus turnos. Intentá de nuevo.');
        } finally {
            this.isLoadingTurnos = false;
        }
    }
   
    handleConfirmarAsistencia(event) {}
    handleRecoordinar(event) {}
    
    async handleCancelarTurno(event) {
        // Obtenemos el Id del turno desde el dataset del botón configurado en el HTML
        const appointmentId = event.currentTarget.dataset.id;
        
        if (!appointmentId) return;

        this.isLoadingTurnos = true;

        try {
            console.info('Cancelando turno en Salesforce con ID:', appointmentId);
            
            // Llamada al backend
            await cancelarAppointment({ appointmentId: appointmentId });
            
            console.info('Turno cancelado con éxito.');
            
            // Refrescamos la lista de turnos llamando al método que ya consulta el backend
            // Esto asegura que la UI se actualice sola de inmediato
            await this.handleBuscarTurnos();

        } catch (error) {
            console.error('Error al cancelar el turno:', JSON.stringify(error));
            alert('Hubo un problema al cancelar tu turno. Por favor, intenta nuevamente.');
            this.isLoadingTurnos = false;
        }
    }

    // --- ACCIONES ADMIN ---
    handleLoginInput(event) {
        this.passwordIntento = event.target.value;
    }

    intentarLogin() {
        if (this.passwordIntento === 'silvina') { // Password MVP
            this.errorLogin = '';
            this.currentScreen = 'admin';
            this.passwordIntento = ''; // Limpiar
        } else {
            this.errorLogin = 'Contraseña incorrecta.';
        }
    }

    handleAdminLogout() {
        this.currentScreen = 'welcome';
    }

    handleAdminProfFilter(event) {
        this.adminFiltroProf = event.currentTarget.dataset.id;
    }

    handleAdminTab(event) {
        this.adminTab = event.currentTarget.dataset.id;
    }

    // --- NAVEGACIÓN ---
    navToWelcome()     { this.currentScreen = 'welcome'; }
    navToMisTurnos()   { this.currentScreen = 'misTurnos'; this.misTurnosStep = 1; }
    navToPrecios()     { this.currentScreen = 'precios'; }
    navToConsulta()    { this.currentScreen = 'consulta'; }
    navToReserva()     { this.currentScreen = 'reserva'; this.reservaStep = 1; }
    navToEquipoLogin() { this.currentScreen = 'equipo_login'; this.errorLogin = ''; }

    //avanzarPaso2() { this.reservaStep = 2; }

    async avanzarPaso2() {
        // 1. Validación básica del frontend
        if (!this.persona.celular) {
            alert('Por favor, ingresa tu número de celular para continuar.');
            return;
        }

        try {
            // 2. Llamada al backend (Apex)
            const clienteExistente = await getOrCreateCustomer({ phoneNumber: this.persona.celular });
            
            if (clienteExistente.Email__c) {
                console.log('Cliente encontrado en SF: '+ clienteExistente.Id);
                this.reserva.isNewCustomer = false;
                this.persona.email = clienteExistente.Email__c || '';
                this.reserva.customerId = clienteExistente.Id; 
                this.persona.id = clienteExistente.Id; 
                this.persona.firstName = clienteExistente.First_Name__c || '';
                this.persona.lastName = clienteExistente.Last_Name__c || '';
                this.reservaStep = 3;

            } else {
                console.log('No se encontraron registros. Es cliente fue creado con el id: '+ clienteExistente.Id);
                this.reserva.isNewCustomer = true;
                this.reserva.customerId = clienteExistente.Id; 
                this.persona.id = clienteExistente.Id; 
                this.reservaStep = 2; 
            }
            console.info('reserva: ');
            console.info(JSON.stringify(this.reserva));
            console.info('persona: ');
            console.info(JSON.stringify(this.persona));

        } catch (error) {
            console.error('Error al consultar Apex:'+ JSON.stringify(error));
             alert(error.message);
            // TODO
            //this.reservaStep = 2; 

        }
    }

    volverPaso1()  { this.reservaStep = 1; }

    async avanzarPaso3() { 

        if (!this.persona.firstName || !this.persona.firstName.trim()) {
            alert('Por favor, ingresá tu nombre para continuar.');
            return;
        }
        if (!this.persona.lastName || !this.persona.lastName.trim()) {
            alert('Por favor, ingresá tu apellido para continuar.');
            return;
        }
        if (!this.persona.email || !this.persona.email.trim()) {
            alert('Por favor, ingresá tu email para continuar.');
            return;
        }
      
        // update customer
        try{
            const data = { 
                customerId: this.persona.id, 
                firstName: this.persona.firstName, 
                lastName: this.persona.lastName,
                email: this.persona.email,
                comments: this.persona.indicaciones
            };
            console.info('data to update:');
            console.info(JSON.stringify(data));
            const customer = await updateCustomer(data);
            console.info('customer updated: '+customer.Id);

            this.reservaStep = 3; 
        }catch(error){
            console.error('Error updating customer:'+JSON.stringify(error));
            alert(JSON.stringify(error));
        }
       
        }
    //volverPaso2()  { this.reservaStep = 2; }

    volverPaso2() {
        if (this.reserva.isNewCustomer) {
            // Si es nuevo, vuelve a la pantalla de email/indicaciones
            this.reservaStep = 2;
        } else {
            // Si es conocido, vuelve directo al inicio (Nombre/Celular)
            this.reservaStep = 1;
        }
    }
    
    volverPaso3()  { this.reservaStep = 3; }
    volverPaso4()  { this.mostrarSubOpcionesRetiro = false; this.reservaStep = 4; }
    volverPaso5()  { this.reservaStep = 5; }
    volverPasoDesde6() {
        const srv = this.services.find(s => s.Id === this.reserva.servicioSel);
        if (srv && srv.Requiere_Pregunta_Retiro__c) { this.reservaStep = 5; } else { this.reservaStep = 4; }
    }
    avanzarPaso7() { this.reservaStep = 7; } 
    volverPaso6()  { this.reservaStep = 6; }
    volverMisTurnosPaso1() { this.misTurnosStep = 1; }

     // --- DISPONIBILIDAD LÓGICA ---
    goToStep6() {
        console.info('goToStep6');
        this.generarDiasDisponibles();
        this.reservaStep = 6;
    }

    generarDiasDisponibles() {
        console.info('generarDiasDisponibles');
        const DOW = ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'];
        const MESES = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
        let dias = []; 
        let hoy = new Date();
        
        for(let i=1; i<=14; i++) {
            let d = new Date(hoy); 
            d.setDate(d.getDate() + i);
            if(d.getDay() === 0) continue; // Salteamos domingos
            
            let iso = d.toISOString().split('T')[0];
            dias.push({ 
                iso: iso, 
                dow: DOW[d.getDay()], 
                num: d.getDate(), 
                mon: MESES[d.getMonth()], 
                cssClass: 'day-pill' 
            });
        }

        // Auto-seleccionar primer día disponible
        if (dias.length > 0) {
            this.reserva.fechaSel = dias[0].iso;
            dias[0].cssClass = 'day-pill day-pill--selected';
        }
        
        this.diasDisponiblesList = dias;
        this.fetchHorasDisponibles();
    }

   async fetchHorasDisponibles() {
        console.info('fetchHorasDisponibles, date: '+this.reserva.fechaSel+' service: '+this.reserva.servicioSel);
        if (!this.reserva.fechaSel || !this.reserva.servicioSel) return;
        //console.info(JSON.stringify(this.reserva, null, 2));
        
        this.isLoadingHours = true;
        this.horasDisponiblesList = [];
        this.reserva.horaSel = null; 
        this.reserva.slotData = null; // Limpiamos el objeto guardado previamente

        try {
            const params = { 
                serviceId: this.reserva.servicioSel,  
                targetDateStr: this.reserva.fechaSel 
            };
            console.info('getAvailableSlots params: '+JSON.stringify(params));
            const availableSlots = await getAvailableSlots(params);
            
            // Desduplicación: Si hay dos empleadas libres a la misma hora, mostramos un solo botón.
            const uniqueTimes = new Map();
            console.info('availableSlots');
            console.info(JSON.stringify(availableSlots, null, 2));
            availableSlots.forEach(slot => {
                // Usamos hour24 (Ej: '09:00') como clave única
                if (!uniqueTimes.has(slot.hour24)) {
                    uniqueTimes.set(slot.hour24, { 
                        val: slot.hour24, 
                        cssClass: 'slot-btn',
                        slotData: slot // Guardamos el objeto AA_AvailableSlot completo
                    });
                }
            });
            
            // Convertimos el Map a Array para el iterador del HTML
            this.horasDisponiblesList = Array.from(uniqueTimes.values());
            console.info('horasDisponiblesList');
            console.info(JSON.stringify(this.horasDisponiblesList, null, 2));
            
        } catch (error) {
            console.error('Error cargando disponibilidad:', JSON.stringify(error));
        } finally {
            this.isLoadingHours = false;
        }
    }

    handleSelectFecha(event) { 
        console.info('handleSelectFecha, '+event.currentTarget.dataset.fecha);
        this.reserva.fechaSel = event.currentTarget.dataset.fecha; 
        
        // Actualizar visualmente la pastilla del día
        this.diasDisponiblesList = this.diasDisponiblesList.map(d => ({
            ...d,
            cssClass: d.iso === this.reserva.fechaSel ? 'day-pill day-pill--selected' : 'day-pill'
        }));

        this.fetchHorasDisponibles();
    }

    handleSelectHora(event) { 
        console.info('handleSelectHora, '+event.currentTarget.dataset.hora);
        this.reserva.horaSel = event.currentTarget.dataset.hora; 
        
        // Buscamos la hora seleccionada para guardar todos sus detalles
        const selectedItem = this.horasDisponiblesList.find(h => h.val === this.reserva.horaSel);
        if (selectedItem) {
            this.reserva.slotData = selectedItem.slotData;
        }
        
        // Actualizar visualmente el botón de la hora
        this.horasDisponiblesList = this.horasDisponiblesList.map(h => ({
            ...h,
            cssClass: h.val === this.reserva.horaSel ? 'slot-btn slot-btn--selected' : 'slot-btn'
        }));
    }
}