# 查询
use lds714610;

/*
delete from lds714610.taketrainrecord where CarrigeID = 3;

SET SQL_SAFE_UPDATES = 0;
drop procedure if exists addWuhanPassenger;
delimiter //
create procedure addWuhanPassenger()
begin
  set @seatNo = 0;
  set @numOfPassenger = 10;
  repeat
  
    repeat
	  set @randPID = floor(rand()*1000) + @numOfPassenger;
      select PCardID into @randPCardID from passenger where PID = @randPID;
    until @randPCardID is not null end repeat;
    
    prepare getRandTrain from "select TID, SStationID, AStationID into @trainID, @upStationID, @downStationID 
      from train where SDate='2020-1-22' and SStationID in (select SID from station where SName = '武汉') limit 1 offset ?;";
    set @randOffset = floor(rand()*100) + @numOfPassenger;
    EXECUTE getRandTrain using @randOffset;
    
    set @seatNo = (floor(rand()*10) + @seatNo) % 5 + 1;
    
    insert into TakeTrainRecord (PCardID, TID, SStationID, AStationID, CarrigeID, SeatRow, SeatNo) 
      values( @randPCardID, @trainID, @upStationID, @downStationID, 3, 1, substr("ABCEF", @seatNo, 1) );
      
    set @numOfPassenger = @numOfPassenger - 1;
  until  @numOfPassenger = 0 end repeat;
  
end //
delimiter ;

call addWuhanPassenger();
*/



# 1）查询确诊者“张三”的在发病前14天内的乘车记录； 
select * from taketrainrecord where taketrainrecord.PCardID in
  (select p.PCardID from diagnoserecord as d join passenger as p on (p.PName='张三' and d.PCardID = p.PCardID) 
    where exists (select TID from train where datediff(d.fday, date(train.ADateTime)) <= 14) );

# 2）查询所有从城市“武汉”出发的乘客乘列车所到达的城市名； 
select distinct cityName from station where SID 
  in ( select AStationID from train as t join station as s on sname = '武汉' and t.SStationID = s.SID  );

# 3）计算每位新冠患者从发病到确诊的时间间隔（天数）及患者身份信息，并将结果按照发病时间天数的降序排列；
select datediff(dday,fday) as intervalDay, p.PCardID, p.PName, p.Sex, p.Age  
  from diagnoserecord as d join passenger as p on d.PCardID = p.PCardID and DStatus = 1
    order by d.FDay desc;

# 4）查询“2020-01-22”从“武汉”发出的所有列车；
select train.* from train join station on train.SDate='2020-01-22' 
  and station.SName = '武汉' and train.SStationID = station.SID;


# 5）查询“2020-01-22”途经“武汉”的所有列车；
select * from train where TID in (select TID from trainpass join station 
  on date(trainpass.ADatetime)='2020-01-22' and station.SName = '武汉' and trainpass.SID = station.SID);

# 6）查询“2020-01-22”从武汉离开的所有乘客的身份证号、所到达的城市、到达日期； 
select t1.PCardID, CityName, date(ADateTime) as ADate from trainpass join station on trainpass.SID = station.SID 
  join taketrainrecord as t1 on t1.TID = trainpass.TID and t1.AStationID = trainpass.SID where exists
    (select TID from trainpass  t2 where t1.TID = t2.TID and t1.SStationID = t2.SID 
       and t2.SID = (select SID from station where SName = '武汉') and date(t2.LDateTime) = '2020-01-22');

# 7）统计“2020-01-22” 从武汉离开的所有乘客所到达的城市及达到各个城市的武汉人员数。
select s1.CityName, count(*) as PNum from taketrainrecord as t1 join station as s1 on (t1.AStationID = s1.SID)
  where exists (select TID from trainpass as t2 join station as s2 on (s2.SName = '武汉' and t2.SID = s2.SID) 
    where t2.TID = t1.TID and t2.SID = t1.SStationID and date(t2.LDateTime) = '2020-01-22') 
      group by s1.CityName;

# 8）查询2020年1月到达武汉的所有人员；
select * from passenger as p1 where exists(
  select t1.TID from taketrainrecord as t1 join station as s1 on t1.AStationID = s1.SID and s1.SName='武汉' 
    join trainpass as t2 on t1.TID = t2.TID and t1.AStationID=t2.SID and month(t2.ADateTime) = 1);


# 9） 查询2020年1月乘车途径武汉的外地人员（身份证非“420”开头）；
select * from passenger as p1 where left(p1.PCardID, 3)='420' and exists(
  select t1.TID from taketrainrecord as t1 join station as s1 on t1.AStationID = s1.SID and s1.SName='武汉' 
    join trainpass as t2 on t1.TID = t2.TID and t1.AStationID=t2.SID and month(t2.ADateTime) = 1);
    

# 10）统计“2020-01-22”乘坐过‘G007’号列车的新冠患者在火车上的密切接触乘客人数（每位新冠患者的同车厢人员都算同车密切接触）。
select count(*) as contactorNum from traincontactor as t1 where exists (
  select t2.TID from taketrainrecord t2 join train as t3 on t3.TID = t2.TID and t3.TName = 'G007' 
    join trainpass as t4 on t4.TID = t3.TID and t4.SID = t3.SStationID and date(t4.LDateTime)='2020-1-22' where t1.PCardID = t2.PCardID );

# 11）查询一趟列车的一节车厢中有3人及以上乘客被确认患上新冠的列车名、出发日期，车厢号； 
select t1.TName, t1.SDate, t2.CarrigeID from train as t1 join taketrainrecord as t2 on t1.TID = t2.TID 
  join diagnoserecord as d1 on d1.PCardID = t2.PCardID and d1.DStatus = 1 
    group by t1.TName, t1.SDate, t2.CarrigeID having count(*) >= 3;

# 12）查询没有感染任何周边乘客的新冠乘客的身份证号、姓名、乘车日期；
select d1.PCardID, p1.PName, date(t2.LDateTime) as LDate from diagnoserecord as d1 join passenger as p1 on d1.PCardID = p1.PCardID and d1.DStatus = 1
  join taketrainrecord as t1 on t1.PCardID = d1.PCardID 
    join trainpass as t2 on t2.TID = t1.TID and t2.SID = t1.SStationID
      where not exists ( select * from traincontactor as t3 where t3.PCardID = d1.PCardID and DStatus = 1 );
 
# 13）查询到达 “北京”、或“上海”，或“广州”（即终点站）的列车名，要求where子句中除了连接条件只能有一个条件表达式；
select distinct TName from train where AStationID in (select SID from station where field(SName, '北京','上海','广州') > 0 );


# 14）查询“2020-01-22”从“武汉站”出发，然后当天换乘另一趟车的乘客身份证号和首乘车次号，结果按照首乘车次号降序排列，同车次则按照乘客身份证号升序排列；
select t1.PCardID, t1.TID from taketrainrecord as t1 join station as s1 on SName = '武汉' and s1.SID = t1.SStationID
  join trainpass as t2 on t1.TID=t2.TID and t1.SStationID = t2.SID and date(LDateTime) = '2020-1-22'
    where exists ( select t3.PCardID from taketrainrecord as t3 join trainpass as t4 on t3.TID = t4.TID and t3.SStationID = t4.SID
      where t3.PCardID = t1.PCardID and date(t4.LDateTime) = '2020-1-22' group by t3.PCardID having count(t3.PCardID) > 1)
        order by t1.TID desc, PCardID asc;


# 15）查询所有新冠患者的身份证号，姓名及其2020年以来所乘坐过的列车名、发车日期，要求即使该患者未乘坐过任何列车也要列出来；
select d1.PCardID, p1.PName, t3.TName, date(t2.LDateTime) from diagnoserecord as d1 join passenger as p1 on d1.DStatus=1 and d1.PCardID = p1.PCardID
  join taketrainrecord as t1 on t1.PCardID = d1.PCardID join train as t3 on t3.TID = t1.TID
    join trainpass as t2 on t2.TID = t1.TID and t1.SStationID = t2.SID and year(t2.LDateTime) = '2020';

# 16）查询所有发病日期相同而且确诊日期相同的病患统计信息，包括：发病日期、确诊日期和患者人数，结果按照发病日期降序排列的前提下再按照确诊日期降序排列。
select fday, dday, count(*) as Dcnt from diagnoserecord where DStatus = 1 group by FDay, DDay order by FDay desc, DDay desc;
