# 车站表【车站编号，车站名，所属城市】
# Station (SID int, SName char, CityName char)
# 车次表【列车流水号，发车日期，列车名称，起点站编号，终点站编号，开出时刻，终点时刻】
# Train (TID ,SDate date, TName char(20), SStationID int, AStationID int, SDateTime datetime, ADateTime datetime )
# 车程表【列车流水号，车站序号，车站编号，到达时刻，离开时刻】
# TrainPass (TID int, SNo smallint, SID int, ADateTime datetime,LDateTime datetime)
# 乘客表【乘客身份证号，姓名，性别，年龄】
# Passenger ( PCardID char(18), PName char(20),Sex bit, Age smallint)

# 乘车记录表【记录编号，乘客身份证号，列车流水号，出发站编号，到达站编号，
	# 车厢号，席位排号，席位编号，席位状态】
/*TakeTrainRecord (RID , PCardID char(18), TID int, SStationID int, AStationID int, 
CarrigeID smallint, 	# null means no seat CarrigeID若为空，则表示“无座”； 
SeatRow smallint,SeatNo char(1),		# A-C, E-F or null
SStatus int,		# 0:return a check退票, 1:formal, 2:passenger didn't get on )
*/
# 诊断表【诊断编号，病人身份证号，诊断日期，诊断结果，发病日期】
/* DiagnoseRecord (DID, PCardID char(18), DDay date, 
    DStatus smallint,  # 1：新冠确诊；2：新冠疑似；3：排除新冠
    FDay date)
*/
# 乘客紧密接触者表【接触日期, 被接触者身份证号，状态，病患身份证号】
# TrainContactor (CDate date, CCardID char(18),DStatus smallint, PCardID char(18))

    
# 2019-1-01到2020-2-01
# 不区分大小写
use lds714610;
set @@sql_mode = replace( replace(@@sql_mode,"NO_ZERO_IN_DATE,", ""), "NO_ZERO_DATE,", "" );

    
truncate table DiagnoseRecord;
drop procedure if exists createDataOfDiagnoseRecord;
delimiter //
create procedure createDataOfDiagnoseRecord()
begin

set @patientNum  := 15;		#生成病人的数目
set @patientRID := 0;		#病人的乘车记录ID

select count(*) into @passengerTol from taketrainrecord;		#获取乘客记录总数

# 诊断表【诊断编号，病人身份证号，诊断日期，诊断结果，发病日期】
/* DiagnoseRecord (DID, PCardID char(18), DDay date, 
    DStatus smallint,  # 1：新冠确诊；2：新冠疑似；3：排除新冠
    FDay date)
*/

repeat 
	repeat
		set @patientRID = (floor(rand()*100) + @patientRID );		#在前一百名乘客中随机生成病人	生成的是伪随机，可能会死循环
		select PCardID, tid into @patientID, @trainID from taketrainrecord where rid = @patientRID;
		select did into @hadSameID from DiagnoseRecord where PCardID = @patientID;		#确保不是同一个乘客
    until (@hadSameID is null) end repeat;
    
    set @patientStatus = floor(rand()*10) % 3 + 1;		#病人诊断结果
    
    select ADateTime into @refDateTime from train where tid = @trainID;	#当天列车的到达日期
    set @intrlDay = floor(rand()*10) % 10;
    if (@patientStatus = 1) then
		set @onsetDate = date_add( date(@refDateTime), interval @intrlDay day );	#生成发病日期
	else 
		set @onsetDate = "0000-0-0 0:0:0";
	end if;
    
    set @refDateTime = date_add( date(@refDateTime), interval @intrlDay day );
    set @intrlDay = floor(rand()*10) % 3;
    set @diagnoseDate = date_add( date(@refDateTime), interval @intrlDay day );		#生成诊断日期
    
    insert into DiagnoseRecord(PCardID, DDay, DStatus, FDay) values ( @patientID, @diagnoseDate, @patientStatus, @onsetDate );
    
	set @patientNum = @patientNum - 1;
until @patientNum = 0 end repeat;

end //
delimiter ;


call createDataOfDiagnoseRecord();



