create table visitors
(   name varchar(256),
    public_message varchar(16384),
    private_message varchar(16384),
    time timestamp not null
);
create index visitors_by_date on visitors (time asc);
