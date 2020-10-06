
export default function define(runtime, observer) {
  const main = runtime.module();
  main.variable(observer()).define(["md"], function(md){return(
md`# Runner Locations based on User Submissions over Time

This animation shows the route locations from the race submissions over time. The first submission is <svg width=8 height=16><circle cx=4 cy=10 r=4 fill=blue></circle></svg>.`
)});
  main.variable(observer("viewof replay")).define("viewof replay", ["html"], function(html){return(
html`<button>Replay`
)});
  main.variable(observer("replay")).define("replay", ["Generators", "viewof replay"], (G, _) => G.input(_));
  main.define("initial date", function(){return(
null
)});
  main.variable(observer("mutable date")).define("mutable date", ["Mutable", "initial date"], (M, _) => new M(_));
  main.variable(observer("date")).define("date", ["mutable date"], _ => _.generator);
  main.variable(observer("chart")).define("chart", ["replay","d3","data","DOM","topojson","us","mutable date"], function(replay,d3,data,DOM,topojson,us,$0)
{
  replay;

  const width = 960;
  const height = 600;
  const path = d3.geoPath();

  const delay = d3.scaleTime()
      .domain([data[0].date, data[data.length - 1].date])
      .range([0, 20000]);

  const svg = d3.select(DOM.svg(width, height))
      .style("width", "100%")
      .style("height", "auto");

  svg.append("path")
      .datum(topojson.merge(us, us.objects.lower48.geometries))
      .attr("fill", "#ddd")
      .attr("d", path);

  svg.append("path")
      .datum(topojson.mesh(us, us.objects.lower48, (a, b) => a !== b))
      .attr("fill", "none")
      .attr("stroke", "white")
      .attr("stroke-linejoin", "round")
      .attr("d", path);

  const g = svg.append("g")
      .attr("fill", "red")
      .attr("stroke", "black");

  svg.append("circle")
      .attr("fill", "blue")
      .attr("transform", `translate(${data[0]})`)
      .attr("r", 3);

  for (const d of data) {
    d3.timeout(() => {
      g.append("circle")
          .attr("transform", `translate(${d})`)
          .attr("r", 3)
          .attr("fill-opacity", 1)
          .attr("stroke-opacity", 0)
        .transition()
          .attr("fill-opacity", 0)
          .attr("stroke-opacity", 1);
    }, delay(d.date));
  }

  svg.transition()
      .ease(d3.easeLinear)
      .duration(delay.range()[1])
      .tween("date", () => {
        const i = d3.interpolateDate(...delay.domain());
        return t => $0.value = d3.timeDay(i(t));
      });

  return svg.node();
}
);
  main.variable(observer("data")).define("data", ["d3"], async function(d3)
{
  const parseDate = d3.timeParse("%Y-%m-%d %H:%M:%S");
  const projection = d3.geoAlbersUsa().scale(1280).translate([480, 300]);
  const data = await d3.csv("./long_lat_date.csv", d => {
    const p = projection(d);
    p.date = parseDate(d.date);
    return p;
  });
  data.sort((a, b) => a.date - b.date);
  return data;
}
);
  main.variable(observer("us")).define("us", ["d3"], async function(d3)
{
  const us = await d3.json("https://unpkg.com/us-atlas@1/us/10m.json");
  us.objects.lower48 = {
    type: "GeometryCollection",
    geometries: us.objects.states.geometries.filter(d => d.id !== "02" && d.id !== "15")
  };
  return us;
}
);
  main.variable(observer("topojson")).define("topojson", ["require"], function(require){return(
require("topojson-client@3")
)});
  main.variable(observer("d3")).define("d3", ["require"], function(require){return(
require("d3@5")
)});
  return main;
}
