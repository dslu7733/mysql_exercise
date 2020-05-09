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

# 生成表格TakeTrainRecord的数据
# 由于车程表的数据达到上万，所以这里假设每辆车只有2节车厢，每节车厢至少10人。
    
truncate table taketrainrecord;
drop procedure if exists createDataOfTrainRecord;
delimiter //
create procedure createDataOfTrainRecord()
begin
    declare trainID int;
    declare stationID int;
	declare passengerTol int;
    declare cardID char(18);			#身份证号
    declare sNoMax int ;				#一趟列车一共经过的车站数目
    -- declare done boolean default 0;
    declare trainPassCur cursor for select TID, SID from TrainPass; # 游标放后面
    -- declare continue handler for not found set done = 1;
  
	# declare trainSno int;		#不要起与表属性相同的名字，会有很多奇怪的bug
    # 求出乘客ID总数
    set passengerTol = (select count(*) from passenger);
    open trainPassCur;
    fetch trainPassCur into trainID, stationID;
    set @preTID := -1;
    set @carrageID := 1;		# 车厢号 1/2
    set @tolNum := 0;			#车厢总人数
    set @seatRow := 1;			#排号
    set @seatNo := 1;			#座位号
    set @passengerNum = 1;		#人数记录, auto_increment，default 0 从1开始
    set @upSNo = 0;				#上车时的站点
    set @downSNo = 0;			#下车的站点
    
    select SID into @wuhanSID from station where sname = "武汉";

/*TakeTrainRecord (RID , PCardID char(18), TID int, SStationID int, AStationID int, 
CarrigeID smallint, 	# null means no seat CarrigeID若为空，则表示“无座”； 
SeatRow smallint,SeatNo char(1),		# A-C, E-F or null
SStatus int,		# 0:return a check退票, 1:formal, 2:passenger didn't get on )
*/
    repeat	#开始遍历
		if (@preTID != trainID) then  	#同一列车流水
			
            repeat 		# 2个车厢
				set @tolNum := floor( rand() * 10 + 10 );	#生成一个车厢的随机乘客数目
				set @seatRow := 1;							# 乘客座位总是在空位里面抽第一个
				set @seatNo := 1;
                set sNoMax = ( select count(*) from TrainPass where TID = trainID );	#这趟车经过的站点数目
                
				repeat					#一个车厢的乘客	
					if @passengerNum <= passengerTol then		#获取乘客身份证信息
						select PCardID into cardID from Passenger where PID = @passengerNum;  #因为不区分大小写，注意别同名搞混
					else
						set @passengerNum := 1;
						select PCardID into cardID from Passenger where PID = @passengerNum;
					end if;
                    
                    # 确定上车点和下车点
                    -- select min(sno) into @upSNo from trainpass where tid = trainID and sID = @wuhanSID;		#尽量包含武汉站
                    -- select min(sno), @wuhanSID from trainpass where tid = trainID and sID = @wuhanSID;	
                    set @upSNo := floor((rand() * 100)) % (sNoMax - 1) + 1;		# -1是不包括最后一站
                    
                    set @downSNo := @upSNo + floor((rand() * 100)) % (sNoMax - @upSNo) + 1;		# +1是不包括起点站
                    select  SID into @upStationID from TrainPass where TID = trainID and SNo = @upSNo ;
                    select  SID into @downStationID from TrainPass where TID = trainID and SNo = @downSNo ;
                    
                    # 插入一个乘客的数据
                    insert into TakeTrainRecord (PCardID, TID, SStationID, AStationID, CarrigeID, SeatRow, SeatNo) 
						values( cardID, trainID, @upStationID, @downStationID, @carrageID, @seatRow, substr("ABCEF", @seatNo, 1) );
                    
                    set @passengerNum := @passengerNum + 1;
                    set @seatRow := @seatRow + floor(@seatNo/5);
                    set @seatNo := (@seatNo + 1) % 5 + 1;
					set @tolNum :=  @tolNum - 1;
				until @tolNum = 0 end repeat;		#乘客数目清零，结束循环
                
                set @carrageID := @carrageID + 1;
			until @carrageID > 2 end repeat;	
        
        
			set @carrageID := 1;		# 车厢号 1/2
            set @preTID := trainID;
		end if;
        
		fetch trainPassCur into trainID, stationID;
        if( @passengerNum > 900 ) then 		# 特意添加武汉出发的乘客
			repeat
				fetch trainPassCur into trainID, stationID;
            until stationID = @wuhanSID end repeat;
		end if;
    until @passengerNum > 1000 end repeat;		# 遍历结束, 生成不少于10000个乘客
    close trainPassCur;
end //
delimiter ;



call createDataOfTrainRecord();
























