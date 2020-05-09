use lds714610;
set @@sql_mode = replace( replace(@@sql_mode,"NO_ZERO_IN_DATE,", ""), "NO_ZERO_DATE,", "" );
SET SQL_SAFE_UPDATES = 0;
-- select @@secure_file_priv;


# 1
/*
-- update TakeTrainRecord set SStatus = 1 where RID = 1;
select * from TakeTrainRecord where RID = 1;
delete from TakeTrainRecord where RID = 1;
insert into TakeTrainRecord(RID, PCardID, TID, SStationID, AStationID, CarrigeID, SeatRow, SeatNo, SStatus) 
						values( 1, '150621196302132688', '11376', '2020', '79', '1', 1, 'A', 1);
update TakeTrainRecord set SStatus = 0 where RID = 1;
select * from TakeTrainRecord where RID = 1;
*/

# 2 批操作
/*
drop table if exists WH_TakeTrainRecord;
create table if not exists WH_TakeTrainRecord (
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

insert into WH_TakeTrainRecord SELECT * FROM lds714610.taketrainrecord wuhan where SStationID = (select SID from station where sname="武汉");
*/


# 3. 导入和导出数据
/*
drop table if exists TrainBK;
create table TrainBK (
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
	
select * from train into outfile 'C:/Program1/mysql-8.0.13-winx64/export_import/train.txt';
select @@local_infile;
-- SET GLOBAL local_infile=1; 
-- load data local infile 'C:/Program1/mysql-8.0.13-winx64/export_import/train.txt' into table TrainBK;
*/


# 4. 观察实验
/*
drop table if exists test;
create table if not exists test(
	x int default 0
);
insert into test values(1),(1),(2),(2);
select * from test;
delete from test where x = 1;
select * from test;
update test set x = 3 where x = 2;
select * from test;
*/


# 5. 创键视图
/*
身份证号、姓名、年龄、乘坐列车编号、发车日期、车厢号，席位排号，席位编号。
*/
/* insert into TakeTrainRecord (PCardID, TID, SStationID, AStationID, CarrigeID, SeatRow, SeatNo) 	#令同一个病人有2次乘车记录
						values( '320925194103132161', '11388', '63', '1', '1', '1', 'B');
*/
/*
create view patient(pCardID, pName, age, tid, SDate, carrigeID, seatRow, seatNo ) as 
	select t.pCardID, pname, age, t.tid, date(LDatetime) as SDate, CarrigeID, SeatRow, SeatNo from diagnoserecord as d join taketrainrecord as t 
		on (DStatus = 1 and SStatus = 1 and d.PCardID = t.PCardID) join passenger as p on p.PCardID = d.PCardID 
			join trainpass on trainpass.TID = t.TID and t.SStationID = trainpass.SID order by t.PCardID, SDate desc;

select * from patient;
drop view if exists patient;
*/


# 6. 触发器
/*
1) 当新增一个确诊患者时，若该患者在发病前14天内有乘车记录，
则将其同排及前后排乘客自动加入“乘客紧密接触者表”，其中：接触日期为乘车日期。
2) 当一个紧密接触者被确诊为新冠时，从“乘客紧密接触者表”中修改他的状态为“1”。

【接触日期, 被接触者身份证号，状态，病患身份证号】
TrainContactor (CDate date, CCardID, DStatus, PCardID)
*/
drop procedure if exists updateContactor;
delimiter //
create procedure updateContactor(
	in in_tID int,
    in in_patientID char(18),
    in in_carrigeID smallint,
    in in_seatRow smallint,
    in in_seatNo char(1),
    in in_patientSSNo int, 
    in in_patientASNo int
) comment "insert or edit data to TrainContactor"
begin
	declare done boolean default 0;
    declare contactorSeatRow smallint;
    declare contactorSeatNo char(1); 
    declare contactorPCardID char(18);
    declare contactorSSID int;
    declare contactorASID int;
    
	declare contactorCur cursor for select seatRow, seatNo, pCardID, sstationID, astationID from taketrainrecord	#与病人同一车次同一车厢的乘客
		where tid = in_tID and carrigeId = in_carrigeID and sstatus = 1;
            
	declare continue handler for not found set done = 1;
    
	open contactorCur;
    fetch contactorCur into contactorSeatRow, contactorSeatNo, contactorPCardID, contactorSSID, contactorASID;
    repeat
        if abs(contactorSeatRow - in_seatRow) < 2 then		#先判断该乘客是否是相邻行
			select SNo into @contactorSSNo from trainpass where tid = in_tID and SID = contactorSSID;
            select SNo into @contactorASNo from trainpass where tid = in_tID and SID = contactorASID;
            if ( (in_patientSSNo <= @contactorSSNo  and  in_patientSSNo < @contactorASNo ) 
				or (in_patientASNo > @contactorSSNo  and  in_patientASNo <= @contactorASNo) ) then	#判断是否相遇过
                
                -- select pname from passenger where pcardID = contactorPCardID;		#输出接触者姓名
                
				if( contactorSeatRow != in_seatRow or contactorSeatNo != in_seatNo) then		#接触者
					select count(DID) into @diagnosed from diagnoserecord where PCardID = contactorPCardID;	#判断接触者是否已经诊断过
					if  @diagnosed = 0 then							#接触者未诊断过	
						select count(CCardID) into @contacted from TrainContactor where CCardID = contactorPCardID;	#判断是否已经记录为接触者
						if @contacted = 0 then 			#还未必记录
							set @encounterSNo = if( @contactorSSNo>in_patientSSNo, @contactorSSNo, in_patientSSNo );	#确定第一次相遇的日期
                            select date(LDateTime) into @encounterDate from trainpass where TID = in_tID and SNo = @encounterSNo;
							insert into TrainContactor(CDate, CCardID, DStatus, PCardID) values ( @encounterDate, contactorPCardID, 2, in_patientID  );
						end if;
					end if;
				else			#患者本人
					select count(CCardID) into @everContacted from TrainContactor where CCardID = in_patientID;		#判断病人曾经是否是接触者
					if @everContacted = 1 then
						update TrainContactor set DStatus = 1 where CCardID = in_patientID;
					end if;
				end if;		#接触者
                
            end if;		#判断是否相遇过
        end if;		#先判断该乘客是否是相邻行
        
		fetch contactorCur into contactorSeatRow, contactorSeatNo, contactorPCardID, contactorSSID, contactorASID;
   until done = 1 end repeat;
    
    close contactorCur;
end //
delimiter ;


create view patientView(pCardID, tid, ADate, carrigeID, seatRow, seatNo, AStationID, SStationID ) as 	#该视图获取病人相关信息
	select t.pCardID, t.tid, date(trainpass.ADatetime) as ADate, CarrigeID, SeatRow, SeatNo, t.AStationID, t.SStationID from diagnoserecord as d 
		join taketrainrecord as t on (DStatus = 1 and SStatus = 1 and d.PCardID = t.PCardID) 
			join trainpass on trainpass.TID = t.TID and t.AStationID = trainpass.SID;

truncate table TrainContactor;
drop trigger if exists newPatient;
delimiter //
create trigger newPatient after insert on diagnoserecord
for each row
begin
	select count(*)  into @tripNum from patientView 	#一个病人可能乘坐多次列车
		where new.pCardID = patientView.PCardID group by patientView.PCardID;	
    
    while @tripNum > 0 do
    
        select ADate, pCardID, tid, carrigeID, seatRow, seatNo, AStationID, SStationID  	#获取病人该次乘车的信息
			into @arrivalDate, @patientID, @patientTID,  @patientCarrigeID, @patientRow, @patientSeatNo, @patientASID, @patientSSID
				from patientView where new.pCardID = patientView.PCardID;	
        select SNO into @patientSSNo from trainpass where tid =  @patientTID and SID = @patientSSID;
        select SNO into @patientASNo from trainpass where tid =  @patientTID and SID = @patientASID;

		# select  sdate from patient where patient.PCardID = @patientID limit 1 offset @tripTime;	#offet只支持硬编码
		# prepare getSDate from "select Adate into @arrivalDate from patientView where patient.PCardID = @patientID limit 1 offset ?;";	# 触发器不支持
		# EXECUTE getSDate USING @tripTime;	#获取病人的乘车抵达日期
		if (datediff(new.fday, @arrivalDate) <= 14) then		#相距14天以内
			call updateContactor(@patientTID, @patientID, @patientCarrigeID, @patientRow, @patientSeatNo, @patientSSNo, @patientASNo );
		end if;
        
        set @tripNum = @tripNum - 1;
    end while;
end//
delimiter ;

delete from diagnoserecord where pcardID = '150621196302132688';
insert into diagnoserecord(PCardID, DDay, DStatus, FDay) values('150621196302132688', '2019-12-02', '1', '2019-12-02');
drop trigger if exists newPatient;

# 触发器debug
/*
truncate table TrainContactor;
select ADate, pCardID, tid, carrigeID, seatRow, seatNo, AStationID, SStationID  	#获取病人该次乘车的信息
		into @arrivalDate, @patientID, @patientTID,  @patientCarrigeID, @patientRow, @patientSeatNo, @patientASID, @patientSSID
			from patientView where '150621196302132688' = patientView.PCardID;	
select SNO into @patientSSNo from trainpass where tid =  @patientTID and SID = @patientSSID;
select SNO into @patientASNo from trainpass where tid =  @patientTID and SID = @patientASID;
call updateContactor(@patientTID, @patientID, @patientCarrigeID, @patientRow, @patientSeatNo, @patientSSNo, @patientASNo );
drop view if exists patientView;
*/


# 16:33:24	insert into diagnoserecord(PCardID, DDay, DStatus, FDay) values('150621196302132688', '2019-12-02', '1', '2019-12-02')	Error Code: 1055. Expression 
#3 of SELECT list is not in GROUP BY clause and contains nonaggregated column 'patientView.tid' which is not functionally dependent on columns in GROUP BY clause; 
# this is incompatible with sql_mode=only_full_group_by	0.016 sec









