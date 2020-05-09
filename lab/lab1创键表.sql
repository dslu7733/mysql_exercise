create database if not exists lds714610;
use lds714610;

# 暂时关闭外键约束
SET FOREIGN_KEY_CHECKS = 0;
# 修改sql模式，令datetime类型数据可以为0
set @@sql_mode = replace( replace(@@sql_mode,"NO_ZERO_IN_DATE,", ""), "NO_ZERO_DATE,", "" );

# 车站表【车站编号，车站名，所属城市】
drop table if exists Station;
create table Station (
	SID int not null, 
    SName char(20) not null, 
    CityName char(20) not null,
    primary key(SID) 
    )ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci;
    
    
# 车次表【列车流水号，发车日期，列车名称，起点站编号，终点站编号，开出时刻，终点时刻】
drop table if exists Train;
create table Train (
	TID int not null auto_increment, 
    SDate date not null, 
    TName char(20) not null, 
    SStationID int, 
    AStationID int, 
    SDateTime datetime default "0000-0-0 0:0:0", 
    ADateTime datetime default "0000-0-0 0:0:0",
    primary key(TID),
    foreign key(SStationID) references Station(SID),
    foreign key(AStationID) references Station(SID),
    unique(TName, SDate) 	#候选码， 在unique的列是可以多次插入空值
    )ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci, auto_increment = 0;		
   
   
# 车程表【列车流水号，车站序号，车站编号，到达时刻，离开时刻】
drop table if exists TrainPass;
create table TrainPass (
	TID int, 
    SNo smallint, 
    SID int, 
    ADateTime datetime default "0000-0-0 0:0:0",
    LDateTime datetime default "0000-0-0 0:0:0",
    primary key(TID,SNo),
    foreign key(SID) references Station(SID)
    )ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci;
    


# 乘客表【乘客身份证号，姓名，性别，年龄】
drop table if exists Passenger;
create table Passenger (
	PID int not null auto_increment,
	PCardID char(18), 
    PName char(20), 
    Sex bit, 
    Age smallint,
    primary key(PCardID),
    unique (PID)
    )ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci, auto_increment = 0;


# 乘车记录表【记录编号，乘客身份证号，列车流水号，出发站编号，到达站编号，
# 车厢号，席位排号，席位编号，席位状态】
drop table if exists TakeTrainRecord;
create table TakeTrainRecord (
	RID int not null auto_increment, 
    PCardID char(18), 
    TID int, 
    SStationID int, 
    AStationID int, 
    CarrigeID smallint, 	# null means no seat
    SeatRow smallint,
    SeatNo char(1),		# A-C, E-F or null
    SStatus int not null default 1,		# 0:return a check退票, 1:formal, 2:passenger didn't get on
    primary key(RID),
    foreign key(PCardID) references Passenger(PCardID),
    foreign key(TID) references Train(TID),
    foreign key(SStationID) references Station(SID),
    foreign key(AStationID) references Station(SID)
    )ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci, auto_increment = 0;



# 诊断表【诊断编号，病人身份证号，诊断日期，诊断结果，发病日期】
drop table if exists DiagnoseRecord;
create table DiagnoseRecord (
	DID int not null auto_increment, 
    PCardID char(18), 
    DDay date, 
    DStatus smallint,  # 1：新冠确诊；2：新冠疑似；3：排除新冠
    FDay date,
    primary key(DID),
    foreign key(PCardID) references Passenger(PCardID)
    )ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci, auto_increment = 0;


# 乘客紧密接触者表【接触日期, 被接触者身份证号，状态，病患身份证号】
drop table if exists TrainContactor ;
create table TrainContactor (
	CDate date, 
    CCardID char(18), 
    DStatus smallint, 
    PCardID char(18),
    foreign key(PCardID) references Passenger(PCardID)
    )ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci;










SET FOREIGN_KEY_CHECKS = 1;







    