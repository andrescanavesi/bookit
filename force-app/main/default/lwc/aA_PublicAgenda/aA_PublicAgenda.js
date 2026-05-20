import { LightningElement, track } from 'lwc';

import getOrCreateCustomer from '@salesforce/apex/AA_PublicAgendaController.getOrCreateCustomer';
import getCategories from '@salesforce/apex/AA_PublicAgendaController.getCategories';
import getServices from '@salesforce/apex/AA_PublicAgendaController.getServices';
import updateCustomer from '@salesforce/apex/AA_PublicAgendaController.updateCustomer';

export default class AAPublicAgenda extends LightningElement {
    // --- ESTADO GLOBAL ---
    currentScreen = 'welcome';
    reservaStep = 1;
    misTurnosStep = 1;

    @track categories = [];
    @track services = [];

    @track persona = { id: '', nombre: '', celular: '', email: '', preferencias: '', indicaciones: '' };
    @track reserva = { grupoSel: null, servicioSel: null, 
    retiro: null, fechaSel: null, horaSel: null, formaPago: null, isNewCustomer: true,
    customerId: null };
    @track misTurnosLogin = { nombre: '', celular: '' };

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
    get primerNombre() { return this.persona.nombre ? this.persona.nombre.split(' ')[0] : ''; }
    get primerNombreMisTurnos() { return this.misTurnosLogin.nombre ? this.misTurnosLogin.nombre.split(' ')[0] : ''; }

    get preciosAgrupados() {
       return this.categoriasBD.map(cat => {
            const serviciosDelGrupo = this.serviciosBD
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
      if (!this.reserva.grupoSel) return [];
        
        return this.serviciosBD
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
    }

    get servicioSeleccionadoInfo() {
        if (!this.reserva.servicioSel) return null;
        return this.serviciosFiltrados.find(s => s.Id === this.reserva.servicioSel);
    }

    get turnosEncontrados() { return [{ Id: 'turno_001', fechaStr: 'mar 5 de mayo', horaStr: '09:00', servicio: 'Manicuría sin esmalte', profesional: 'Soledad' }]; }

    get diasDisponibles() { 
        const DOW = ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'];
        const MESES = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
        let dias = []; let hoy = new Date();
        for(let i=1; i<=14; i++) {
            let d = new Date(hoy); d.setDate(d.getDate() + i);
            if(d.getDay() === 0) continue; 
            let iso = d.toISOString().split('T')[0];
            let isSelected = this.reserva.fechaSel === iso;
            dias.push({ iso: iso, dow: DOW[d.getDay()], num: d.getDate(), mon: MESES[d.getMonth()], cssClass: isSelected ? 'day-pill day-pill--selected' : 'day-pill' });
        }
        if (!this.reserva.fechaSel && dias.length > 0) { this.reserva.fechaSel = dias[0].iso; dias[0].cssClass = 'day-pill day-pill--selected'; }
        return dias;
    }

    get horasDisponibles() { 
        if (!this.reserva.fechaSel) return [];
        const horasMock = ['09:00', '11:00', '11:30', '13:00', '14:00', '14:30', '16:00', '16:30', '17:30', '18:00', '19:00'];
        return horasMock.map(h => ({ val: h, cssClass: this.reserva.horaSel === h ? 'slot-btn slot-btn--selected' : 'slot-btn' }));
    }

    get isBotonFechaContinuarDeshabilitado() { return !this.reserva.horaSel; }

    get resumenDatos() {
        if (!this.reserva.servicioSel || !this.reserva.fechaSel) return {};
        const srv = this.serviciosBD.find(s => s.Id === this.reserva.servicioSel);
        // ... formato de fecha existente ...
        let totalCalculado = srv.Precio__c;
        if (this.reserva.retiro && this.reserva.retiro.material === 'blando') totalCalculado += 200;
        if (this.reserva.retiro && this.reserva.retiro.material === 'duro') totalCalculado += 300;
        return { cliente: this.persona.nombre, servicio: srv.Nombre_Visible__c, profesional: 'Soledad', fecha: `mar 5 de mayo`, hora: this.reserva.horaSel, duracion: `${srv.Duracion_Base_Min__c} min`, total: totalCalculado };
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
        this.loadData();
    }

    async loadData() {
        console.info('loading data...');
        try {
            // Cargamos categorías y servicios en paralelo para ganar velocidad
            const [categoriesDB, servicesDB] = await Promise.all([
                getCategories(),
                getServices()
            ]);

            console.info('categories: ');
            console.info(JSON.stringify(categoriesDB));
            console.info('services: ');
            console.info(JSON.stringify(servicesDB));

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
                // ... resto de campos
            }));

        } catch (error) {
            console.error('Error cargando datos:' + JSON.stringify(error));
        }
    }

    handleInputChange(event) { this.persona[event.target.dataset.id] = event.target.value; }
    handleIndicacionesToggle(event) { this.tieneIndicaciones = (event.target.dataset.valor === 'si'); if (!this.tieneIndicaciones) this.persona.indicaciones = ''; }
    
    // avanzar paso 4 (service category selected, now the user has to select the service)
    handleSelectCategoria(event) { 
        this.reserva.grupoSel = event.currentTarget.dataset.id; 
        this.reservaStep = 4; 
        }

    // Al seleccionar un servicio (Paso 4), guardamos su ID y decidimos a dónde ir (Retiro o Fecha)
    handleSelectServicio(event) { 
        const srvId = event.currentTarget.dataset.id; 
        this.reserva.servicioSel = srvId;
        const srv = this.serviciosBD.find(s => s.Id === srvId);
        if (srv && srv.Requiere_Pregunta_Retiro__c) { 
            this.reservaStep = 5; 
        } else { 
            this.reservaStep = 6; 
        }
    }

    handleSelectRetiro(event) {
        const tipo = event.currentTarget.dataset.tipo; this.reserva.retiro = { tipo: tipo };
        if (tipo === 'externo') { this.mostrarSubOpcionesRetiro = true; } else { this.mostrarSubOpcionesRetiro = false; this.reservaStep = 6; }
    }
    handleSelectRetiroMaterial(event) { this.reserva.retiro.material = event.target.dataset.material; this.mostrarSubOpcionesRetiro = false; this.reservaStep = 6; }
    handleSelectFecha(event) { this.reserva.fechaSel = event.currentTarget.dataset.fecha; this.reserva.horaSel = null; }
    handleSelectHora(event) { this.reserva.horaSel = event.currentTarget.dataset.hora; }
    handleSelectPago(event) { this.reserva.formaPago = event.target.dataset.pago; }
    handleConfirmarReserva() { this.reservaStep = 8; }
    handleMisTurnosInput(event) { this.misTurnosLogin[event.target.dataset.id] = event.target.value; }
    handleBuscarTurnos() { if(!this.misTurnosLogin.nombre) { this.misTurnosLogin.nombre = 'Juan'; } this.misTurnosStep = 2; }
    handleConfirmarAsistencia(event) {}
    handleRecoordinar(event) {}
    handleCancelarTurno(event) {}

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
                // ¡El cliente ya existe en Salesforce!
                console.log('Cliente encontrado en SF: '+ clienteExistente.Id);
                this.reserva.isNewCustomer = false;
                this.persona.email = clienteExistente.Email__c || '';
                this.reserva.customerId = clienteExistente.Id; 
                this.persona.id = clienteExistente.Id; 
                this.reservaStep = 3;

            } else {
                // Es un cliente nuevo
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
      
        // update customer
        try{
            const data = { customerId: this.persona.id, fullName: this.persona.nombre, email: this.persona.email};
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
        const srv = this.serviciosBD.find(s => s.Id === this.reserva.servicioSel);
        if (srv && srv.Requiere_Pregunta_Retiro__c) { this.reservaStep = 5; } else { this.reservaStep = 4; }
    }
    avanzarPaso7() { this.reservaStep = 7; } 
    volverPaso6()  { this.reservaStep = 6; }
    volverMisTurnosPaso1() { this.misTurnosStep = 1; }
}