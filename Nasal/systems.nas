####	kodiak systems	####
aircraft.livery.init("Aircraft/kodiak/Models/Liveries", "sim/model/livery/name", "sim/model/livery/index");
var w_fctr=0;
var ViewNum = 0.0;
S_volume = "sim/sound/E_volume";
C_volume = "sim/sound/cabin";
Wiper=[];

FuelSelector=props.globals.getNode("controls/fuel/tank-selector",1);
var FHmeter = aircraft.timer.new("/instrumentation/clock/flight-meter-sec", 10);

#usage :     var wiper = Wiper.new(wiper property , wiper power source (separate from on off switch));
#
#    var wiper = Wiper.new("controls/electric/wipers","systems/electrical/volts");

var Wiper = {
    new : func {
        m = { parents : [Wiper] };
        m.direction = 0;
        m.delay_count = 0;
        m.spd_factor = 0;
        m.node = props.globals.getNode(arg[0],1);
        m.power = props.globals.getNode(arg[1],1);
        if(m.power.getValue()==nil)m.power.setDoubleValue(0);
        m.spd = m.node.getNode("arc-sec",1);
        if(m.spd.getValue()==nil)m.spd.setDoubleValue(1);
        m.delay = m.node.getNode("delay-sec",1);
        if(m.delay.getValue()==nil)m.delay.setDoubleValue(0);
        m.position = m.node.getNode("position-norm", 1);
        m.position.setDoubleValue(0);
        m.switch = m.node.getNode("switch", 1);
        if (m.switch.getValue() == nil)m.switch.setBoolValue(0);
        return m;
    },
    active: func{
    if(me.power.getValue()<=5)return;
    var spd_factor = 1/me.spd.getValue();
    var pos = me.position.getValue();
    if(!me.switch.getValue()){
        if(pos <= 0.000)return;
        }
    if(pos >=1.000){
        me.direction=-1;
        }elsif(pos <=0.000){
        me.direction=0;
        me.delay_count+=getprop("/sim/time/delta-sec");
        if(me.delay_count >= me.delay.getValue()){
            me.delay_count=0;
            me.direction=1;
            }
        }
    var wiper_time = spd_factor*getprop("/sim/time/delta-sec");
    pos +=(wiper_time * me.direction);
    me.position.setValue(pos);
    }
};

#Engine sensors class 
# ie: var Eng = Engine.new(engine number);
var Engine = {
    new : func(eng_num){
        m = { parents : [Engine]};
        m.fdensity = getprop("consumables/fuel/tank/density-ppg");
        if(m.fdensity ==nil)m.fdensity=6.72;
        m.air_temp = props.globals.getNode("environment/temperature-degc",1);
        m.eng = props.globals.getNode("engines/engine["~eng_num~"]",1);
        m.running = m.eng.getNode("running",1);
        m.condition = props.globals.getNode("controls/engines/engine["~eng_num~"]/condition",1);
        m.cutoff = props.globals.getNode("controls/engines/engine["~eng_num~"]/cutoff",1);
        m.mixture = props.globals.getNode("controls/engines/engine["~eng_num~"]/mixture",1);
        m.rpm = m.eng.getNode("n2",1);
        m.fuel_pph=m.eng.getNode("fuel-flow_pph",1);
        m.oil_temp=m.eng.getNode("oil-temp-c",1);
        m.oil_temp.setDoubleValue(m.air_temp.getValue());
        m.fuel_pph.setDoubleValue(0);
        m.fuel_gph=m.eng.getNode("fuel-flow-gph",1);
        m.hpump=props.globals.getNode("systems/hydraulics/pump-psi["~eng_num~"]",1);
        m.hpump.setDoubleValue(0);
    return m;
    },
#### update ####
    update : func{
        me.fuel_pph.setValue(me.fuel_gph.getValue()*me.fdensity);
        var hpsi =me.rpm.getValue();
        if(hpsi>60)hpsi = 60;
        me.hpump.setValue(hpsi);
        var OT= me.oil_temp.getValue();
        var rpm = me.rpm.getValue();
        if(OT < rpm)OT+=0.01;
        if(OT > rpm)OT-=0.001;
        me.oil_temp.setValue(OT);
        },
#### check fuel cutoff , copy mixture setting to condition for turboprop ####
    condition_check :  func{
        if(me.cutoff.getBoolValue()){
            me.condition.setValue(0);
            me.running.setBoolValue(0);
        }else{
            me.condition.setValue(me.mixture.getValue());
        }
    }
};

    var wiper = Wiper.new("controls/electric/wipers","systems/electrical/volts");
    var eng = Engine.new(0);

setlistener("/sim/signals/fdm-initialized", func {
    setprop(S_volume,0.3);
    setprop(C_volume,0.3);
    FuelSelector.setIntValue(0);
    setprop("instrumentation/clock/flight-meter-hour",0);
    print("system  ...Check");
    Shutdown();
    setprop("controls/engines/engine[1]/condition",0);
    settimer(update_systems, 2);
});

setlistener("/sim/signals/reinit", func {
    Shutdown();
});

setlistener("controls/fuel/tank-selector", func(tk){
var tnk = tk.getValue();
if(tnk == -1){
        setprop("consumables/fuel/tank[0]/selected",0);
        setprop("consumables/fuel/tank[1]/selected",1);
    }elsif(tnk == 0){
        setprop("consumables/fuel/tank[0]/selected",1);
        setprop("consumables/fuel/tank[1]/selected",1);
    }elsif(tnk == 1){
        setprop("consumables/fuel/tank[0]/selected",1);
        setprop("consumables/fuel/tank[1]/selected",0);
    }
});

setlistener("/engines/engine/out-of-fuel", func(nf){
    if(nf.getValue() != 0){
        fueltanks = props.globals.getNode("consumables/fuel").getChildren("tank");
        foreach(f; fueltanks) {
            if(f.getNode("selected", 1).getBoolValue()){
                if(f.getNode("level-lbs").getValue() > 0.01){
                    setprop("/engines/engine/out-of-fuel",0);
                }
            }
        }
    }
},0,0);

setlistener("/sim/current-view/view-number", func(vw){
    ViewNum = vw.getValue();
    if(ViewNum == 0){
        setprop(S_volume,0.3);
        setprop(C_volume,0.3);
        }else{
            setprop(S_volume,0.9);
            setprop(C_volume,0.05);
        }
},0,0);

setlistener("/sim/model/start-idling", func(idle){
    var run= idle.getBoolValue();
    if(run){
    Startup();
    }else{
    Shutdown();
    }
},0,0);

setlistener("/gear/gear[1]/wow", func(gr){
    if(gr.getBoolValue()){
    FHmeter.stop();
    }else{FHmeter.start();}
},0,0);


var Startup = func{
setprop("controls/electric/engine[0]/generator",1);
setprop("controls/electric/engine[1]/generator",1);
setprop("controls/electric/avionics-switch",1);
setprop("controls/electric/battery-switch",1);
setprop("controls/electric/inverter-switch",1);
setprop("controls/lighting/instrument-lights",1);
setprop("controls/lighting/instruments-norm",0.8);
setprop("controls/lighting/nav-lights",1);
setprop("controls/lighting/beacon",1);
setprop("controls/lighting/strobe",1);
setprop("controls/engines/engine[0]/mixture",1);
setprop("controls/engines/engine[1]/mixture",1);
setprop("controls/engines/engine[0]/cutoff",0);
setprop("controls/engines/engine[1]/cutoff",0);
setprop("controls/engines/engine[0]/propeller-pitch",1);
setprop("controls/engines/engine[1]/propeller-pitch",1);
setprop("engines/engine[0]/running",1);
setprop("engines/engine[1]/running",1);
}

var Shutdown = func{
setprop("controls/electric/engine[0]/generator",0);
setprop("controls/electric/engine[1]/generator",0);
setprop("controls/electric/avionics-switch",0);
setprop("controls/electric/battery-switch",0);
setprop("controls/electric/inverter-switch",0);
setprop("controls/lighting/instrument-lights",0);
setprop("controls/lighting/instruments-norm",0.8);
setprop("controls/lighting/nav-lights",0);
setprop("controls/lighting/beacon",0);
setprop("controls/lighting/strobe",0);
setprop("controls/engines/engine[0]/mixture",0);
setprop("controls/engines/engine[1]/mixture",0);
setprop("controls/engines/engine[0]/propeller-pitch",0);
setprop("controls/engines/engine[1]/propeller-pitch",0);
setprop("controls/engines/engine[0]/cutoff",0);
setprop("controls/engines/engine[1]/cutoff",0);
setprop("engines/engine[0]/running",0);
setprop("engines/engine[1]/running",0);
}

var flight_meter = func{
var fmeter = getprop("/instrumentation/clock/flight-meter-sec");
var fminute = fmeter * 0.016666;
var fhour = fminute * 0.016666;
setprop("/instrumentation/clock/flight-meter-hour",fhour);
}


##### Main ###########

var update_systems = func {
    var power = getprop("/controls/switches/master-panel");
    eng.update();
    eng.condition_check();
    flight_meter();
    wiper.active();
    settimer(update_systems, 0);
}

