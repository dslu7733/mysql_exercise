use lds714610;
select * from mysql.user;        # 显示该数据库上的所有用户

# 创键账号和密码
create user lds identified by '123';            

# 之后配置用户权限
# lds714610.* 表示 数据库lds714610的所有表
grant create,delete,update,select,insert,drop on lds714610.* to lds;    

# 刷新权限配置
flush privileges;

select * from mysql.user;

# 显示用户的权限
show grants for lds;

# 删除用户
-- drop user lds;