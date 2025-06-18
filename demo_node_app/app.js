const express = require("express");
const app = express();

app.use("/", (req, res) => {
  console.log(req);
  res.json({ url: req.url , message : "Hi Hello from Node!!!"});
});
app.listen(8000, () => {
  console.log("app is listening!!");
});
