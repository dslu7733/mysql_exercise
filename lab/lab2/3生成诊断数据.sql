# 2019-1-01到2020-2-01
# 不区分大小写
use lds714610;
set @@sql_mode = replace( replace(@@sql_mode,"NO_ZERO_IN_DATE,", ""), "NO_ZERO_DATE,", "" );

    
truncate table DiagnoseRecord;	#删除旧的诊断表
drop procedure if exists createDataOfDiagnoseRecord;

delimiter //
create procedure createDataOfDiagnoseRecord()
begin

set @patientNum  := 15;		#生成病人的数目
set @patientRID := 0;		#病人的乘车记录ID
select count(*) into @passengerTol from taketrainrecord;		#获取乘客记录总数

repeat 
	repeat
	  set @patientRID = (floor(rand()*100) + @patientRID );		#随机生成乘客记录ID作为病人 (如果生成的是伪随机，可能会死循环
      select PCardID, tid into @patientID, @trainID from taketrainrecord where rid = @patientRID;
	  select did into @hadSameID from DiagnoseRecord where PCardID = @patientID;		#确保不是同一个乘客
    until (@hadSameID is null) end repeat;	#该乘客未被诊断
    
    set @patientStatus = floor(rand()*10) % 3 + 1;		#病人诊断结果
    
    select ADateTime into @refDateTime from train where tid = @trainID;	#当天列车的到达日期
    set @intrlDay = floor(rand()*10) % 10;
    if (@patientStatus = 1) then	#病人诊断为有病
		set @onsetDate = date_add( date(@refDateTime), interval @intrlDay day );	#生成发病日期
	else 
		set @onsetDate = "0000-0-0 0:0:0";
	end if;
    
    set @intrlDay = @intrlDay + floor(rand()*10) % 3;
    set @diagnoseDate = date_add( date(@refDateTime), interval @intrlDay day );		#生成诊断日期
    
    insert into DiagnoseRecord(PCardID, DDay, DStatus, FDay) 
      values ( @patientID, @diagnoseDate, @patientStatus, @onsetDate );
    
	set @patientNum = @patientNum - 1;
until @patientNum = 0 end repeat;

end //
delimiter ;

call createDataOfDiagnoseRecord();