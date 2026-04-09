from fastapi import FastAPI


app = FastAPI()


@app.get("/")
def fun1():
    return {"field": "value_get"}

@app.delete("/")
def fun2():
    return {"field": "value"}

