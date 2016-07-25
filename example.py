import ibquery, json, time

ib = ibquery.InfoBeamerQuery("127.0.0.1")
io = ib.node("c").io(raw=True)

while 1:
    io.write("u\n%s\n" % json.dumps(dict(
        title = "One set of images",
        images = ["0001", "0002", "0003", "0004", "0005"],
    )))
    io.flush(); time.sleep(4.0)

    io.write("d\n%s\n" % json.dumps(dict(
        title = "(Potentially) another set of images",
        images = ["0001", "0002", "0003", "0004", "0005"],
    )))
    io.flush(); time.sleep(0.5)

    io.write("l\n")
    io.write("l\n")
    io.write("l\n")
    io.write("l\n")
    io.write("l\n")
    io.flush(); time.sleep(5)

    io.write("o\n")
    io.flush(); time.sleep(2)

    io.write("i\n")
    io.flush(); time.sleep(2)
