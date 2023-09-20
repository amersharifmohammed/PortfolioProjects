select *
 from CovidDeaths


 UPDATE CovidDeaths
SET continent = NULL
WHERE continent = ''





   -- Looking at Total Cases vs Total Deaths

 
 SELECT
    location,
    date,
    total_cases,
    total_deaths,
    CASE
        WHEN TRY_CAST(total_cases AS float) IS NOT NULL AND TRY_CAST(total_deaths AS float) IS NOT NULL THEN
            (TRY_CAST(total_deaths AS float) / NULLIF(TRY_CAST(total_cases AS float), 0)) * 100
        ELSE
            0  -- Handle non-numeric values as 0 or adapt as needed
    END AS DeathPercentage
FROM CovidDeaths
WHERE location like '%states%'
ORDER BY DeathPercentage desc

--Looking at Total cases vs Population 

 
 SELECT
    location,
    date,
	population,
    total_cases,
    CASE
        WHEN TRY_CAST(total_cases AS float) IS NOT NULL AND TRY_CAST(population AS float) IS NOT NULL THEN
            (TRY_CAST(total_cases AS float) / NULLIF(TRY_CAST(population AS float), 0)) * 100
        ELSE
            0  -- Handle non-numeric values as 0 or adapt as needed
    END AS PercentagePopulationInfected
FROM CovidDeaths 
WHERE location like '%states%'
order by PercentagePopulationInfected desc



--Looking at Countries with Highest Infection rate compared to population

  
 SELECT 
    cd.location,
    cd.population,
    MAX(cd.total_cases) AS HighestInfectionCount,
    CASE 
        WHEN TRY_CAST(MAX(cd.total_cases) AS float) IS NOT NULL AND TRY_CAST(cd.population AS float) IS NOT NULL THEN
            (TRY_CAST(MAX(cd.total_cases) AS float) / NULLIF(TRY_CAST(cd.population AS float), 0)) * 100
        ELSE
            0  -- Handle non-numeric values as 0 or adapt as needed
    END AS PercentagePopulationInfected
FROM CovidDeaths cd
GROUP BY cd.location, cd.population
ORDER BY PercentagePopulationInfected desc


--Looking countries with highest death count per population


select location, max(cast(total_deaths as int)) as TotalDeathCount

from CovidDeaths 
where continent is not  null
group by location
order by TotalDeathCount desc

--Let's Break things down by continent

select continent, max(cast(total_deaths as int)) as TotalDeathCount

from CovidDeaths 
where continent is not  null
group by continent
order by TotalDeathCount desc

--Global Numbers



SELECT
  
    SUM(new_cases) AS total_cases,
    SUM(CAST(new_deaths AS INT)) AS total_deaths,
    CASE
        WHEN ISNULL(SUM(new_cases), 0) = 0 THEN NULL
        ELSE SUM(CAST(new_deaths AS INT)) * 100.0 / SUM(new_cases)
    END AS DeathPercentage
FROM 
    CovidDeaths
WHERE
    continent IS NOT NULL
--GROUP BY
--    date
ORDER BY
    1, 2;



	DECLARE @Table1Name NVARCHAR(255) = 'coviddeaths';
DECLARE @Table2Name NVARCHAR(255) = 'covidvaccinations';

DECLARE @DynamicSQL NVARCHAR(MAX) = N'';

-- For Table1
SELECT @DynamicSQL = @DynamicSQL + 
    'UPDATE ' + @Table1Name + 
    ' SET ' + QUOTENAME(name) + ' = NULL ' +
    'WHERE ' + QUOTENAME(name) + ' IS NULL OR ' + QUOTENAME(name) + ' = '''';' + CHAR(13)
FROM sys.columns
WHERE object_id = OBJECT_ID(@Table1Name);

-- For Table2
SELECT @DynamicSQL = @DynamicSQL + 
    'UPDATE ' + @Table2Name + 
    ' SET ' + QUOTENAME(name) + ' = NULL ' +
    'WHERE ' + QUOTENAME(name) + ' IS NULL OR ' + QUOTENAME(name) + ' = '''';' + CHAR(13)
FROM sys.columns
WHERE object_id = OBJECT_ID(@Table2Name);

-- Execute the generated SQL
EXEC sp_executesql @DynamicSQL;


--Looking at Total population vs Vaccinations

select dea.continent, dea.location, dea.date, dea.population, vac.total_vaccinations,

case
 when try_cast(dea.population as float) is not null and try_cast(vac.total_vaccinations as float) is not null then
  TRY_CAST(dea.population as float)/nullif(try_cast(vac.total_vaccinations as float),0) *100 

else 
0  

end as TotalVaccinationpopulation

from CovidDeaths  dea
join CovidVaccinations vac
on dea.location = vac.location and
dea.date = vac.date
where dea.continent is not null and dea.location like '%states%'
order by 1,2,3

--Looking at TotalVaccinationsPercentage per population

select dea.location, dea.population, vac.new_vaccinations, dea.date,
sum(convert(int, vac.new_vaccinations)) over (partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated
from CovidDeaths  dea
join CovidVaccinations  vac
on dea.location = vac.location and
dea.date = vac.date
where dea.population is not null and vac.new_vaccinations is not null
order  by 2,3


--Use CTE
with popvsvac (continent, location, date,  population, new_vaccinations, RollingPeopleVaccinated)
as
(
select dea.continent, dea.location,  dea.population, vac.new_vaccinations,dea.date,
sum(convert(float, vac.new_vaccinations)) over (partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated
from CovidDeaths  dea
join CovidVaccinations  vac
on dea.location = vac.location and
dea.date = vac.date
where dea.continent is not null
--order by 2,3
)

select *, CASE 
        WHEN population = 0 THEN NULL
        ELSE (RollingPeopleVaccinated / NULLIF(population, 0)) 
    END AS VaccinationPercentage
FROM  popvsvac
where population is not null and new_vaccinations is not null


 -- Creating temp table


create table #PercentagePopulationVaccinated
(
continent  nvarchar(255),
location    nvarchar(255),
date        datetime,
population        numeric,
new_vaccinations       numeric,
RollingPeopleVaccinated       numeric
)

 insert into #PercentagePopulationVaccinated
 select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
sum(cast(vac.new_vaccinations as float)) over (partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated
from CovidDeaths  dea
join CovidVaccinations  vac
on dea.location = vac.location and
dea.date = vac.date
where dea.population is not null and vac.new_vaccinations is not null

select *,  CASE 
        WHEN population = 0 THEN NULL
        ELSE (RollingPeopleVaccinated / population) * 100
    END AS VaccinationPercentage
 from #PercentagePopulationVaccinated
 where continent is not null



--creating view to store data for later visualizations

create view PercentagePopulationVaccinated as
select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
sum(cast(vac.new_vaccinations as float)) over (partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated
from CovidDeaths  dea
join CovidVaccinations  vac
on dea.location = vac.location and
dea.date = vac.date
where dea.population is not null and vac.new_vaccinations is not null

select * from PercentagePopulationVaccinated